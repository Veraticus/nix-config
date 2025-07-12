// Package main provides basic math operations.
package main

// Add returns the sum of two integers.
func Add(a, b int) int {
	return a + b
}

func main() {
	one := 1
	two := 2
	_ = Add(one, two)
}
