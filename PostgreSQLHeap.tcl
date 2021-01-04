## Hex Fiend Template Script to Annotate PostgreSQL Heap Pages

little_endian

proc item_info_flags { flags } {
    set result ""
    if { $flags == 0x1 } {
        append result "NORMAL"
    }
    if { $flags == 0x2 } {
        append result "REDIRECT"
    }
    if { $flags == 0x3 } {
        append result "DEAD"
    }
    
    return $result
}

### Check if a given value is matching a given bitmask,
### and create an entry with $name with either "YES" or "NO"
proc evaluate_mask { value mask name } {
    set result [expr $value & $mask]
    if { $result == $mask } {
        entry $name "YES"
    } else {
        entry $name "NO"
    }
}

### Flags for the infomask value.
### For reference see https://doxygen.postgresql.org/htup__details_8h_source.html
set infomask_flags [dict create \
    0x0001 "has null attributes" \
    0x0002 "has variable-width attribute(s)" \
    0x0004 "has external stored attribute(s)" \
    0x0008 "has an object-id field" \
    0x0010 "xmax is a key-shared locker" \
    0x0020 "t_cid is a combo cid" \
    0x0040 "xmax is exclusive locker" \
    0x0080 "xmax, if valid, is only a locker" \
    0x0100 "t_xmin committed" \
    0x0200 "t_xmin invalid/aborted" \
    0x0400 "t_xmax committed" \
    0x0800 "t_xmax invalid/aborted" \
    0x1000 "t_xmax is a MultiXactId"
]

### Read the infomask from and set the entries as hexfiend entries.
proc read_infomask {} {
    global infomask_flags
    set value [uint16 "Infomask"]
    section "Info Flags" {
        foreach mask [dict keys $infomask_flags] {
            set name [dict get $infomask_flags $mask]
            evaluate_mask $value $mask $name
        }
    }
}

### The upper bits of infomask2 are bitfield with options (the lower bits)
### is the count of attributes
set infomask2_flags [dict create \
    0x2000 "tuple was updated and key cols modified, or tuple deleted" \
    0x4000 "tuple was HOT-updated" \
    0x8000 "this is heap-only tuple" \
]


### Read the infomask2 and set the values as hexfield entires,
### returning the number of attributes
proc read_infomask2 {} {
    global infomask2_flags
    set value [uint16 "Infomask 2"]
    set attr_count [expr $value & 0x07FF]
    section "Info Flags 2" {
        entry "number of attributes" $attr_count
        foreach mask [dict keys $infomask2_flags] {
            set name [dict get $infomask2_flags $mask]
            evaluate_mask $value $mask $name
        }
        
    }
    return $attr_count
}


section "PostgreSQL database page" {
    set start [pos]
    section "PageHeaderData" {
        uint64 "LSN"
        uint16 "Timeline ID"
        uint16 "Flags"
        set free_start [uint16 "Offset to start of free space (pd_lower)"]
        set free_end [uint16 "Offset to end of free space (pd_upper)"]
        set special_start [uint16 "Offset of start of special space"]
        set page_size_version [uint16 "Page size and layout version number information"]
        set page_size [expr $page_size_version & 0xff00]
        set page_version [expr $page_size_version & 0x00ff]
        entry "Page Size" $page_size
        entry "Page Layout Version" $page_version
        uint32 "Oldest unpruned XMAX on page, or zero if none"
        
    }
    set item_index 0
    
    section "Item Info" {
        set item_index 0

        while {[pos] < $free_start} {
            
            section "Item $item_index" {
                set value [uint32 "ItemIdData Value"]
                set offset [ expr $value & 0x00007FFF ]
                set flags  [ expr $value & 0x00018000 ]
                set length [ expr [ expr $value & 0xFFFE0000 ] >> 17 ] 
                entry "Offset" $offset
                set data_items($item_index) [dict create offset $offset length $length]

                entry "Flags" [item_info_flags [expr $flags >> 15 ]]
                entry "Length" $length
            }
            incr item_index
        }
    }

    bytes [expr $free_end - $free_start ] "Free Space"
    section "Item Data" {
        for { set index 0 }  { $index < [array size data_items] }  { incr index } {
            section "Item Data $index" {
                entry "length" [dict get $data_items($index) "length"]
                entry "offset" [dict get $data_items($index) "offset"]
                set item_start [expr $start + [dict get $data_items($index) "offset"]]
                goto $item_start
                section "Header" {
                    uint32 "Insert XID"
                    uint32 "Delete XID"
                    uint32 "Command ID"
                    uint32 "CTID1"
                    uint16 "CTID2"
                    set attributes [read_infomask2]
                    read_infomask
                    set header_length [uint8 "Header Size including bitmap and padding"]
                    set bitmask 1
                    set byte [uint8]
                    section "null attributes" {
                        for { set column 0}  {$column < $attributes} {incr column} {
                            if { [expr $byte & $bitmask] == $bitmask } {
                                entry "Column $column" "NOT NULL"
                            } else {
                                entry "Column $column" "NULL"
                            }
                            set bitmask [expr $bitmask << 1]
                            if { [expr $column % 7] == 0 && [expr $column != 0] } {
                                set bitmask 1
                                set byte [uint8]
                            }
                        }
                    }
                }
                set data_length [expr [dict get $data_items($index) "length"] - $header_length]
                goto [expr $item_start + $header_length]
                section "Data" {
                    bytes $data_length "data"
                }
            }
        }
    }
}