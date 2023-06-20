package tests

import "core:os"
import "core:fmt"

run_tests :: proc () {
    fmt.println("Hardware Info: ")
    fmt.println("\tArch: ", os.ARCH)
    fmt.println("\tOS: ", os.OS)
    e := os.environ()
    for s in e {
        fmt.println("\t", s)
    }
}