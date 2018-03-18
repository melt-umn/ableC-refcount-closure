// Missing include of refcount.h

int main (int argc, char **argv) {
  closure<(int) -> int> fun = lambda (int x) -> (x + 1);

  return fun(-1);
}
