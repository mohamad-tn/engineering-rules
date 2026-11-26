#include <cstdlib>

int add(int a, int b) { return a + b; }

int main() { return add(1, 2) == 4 ? EXIT_SUCCESS : EXIT_FAILURE; }
