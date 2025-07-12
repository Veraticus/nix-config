package main

import "testing"

func TestMain(t *testing.T) {
    // This test will fail
    t.Fail()
}
EOF < /dev/null