#include <refcount.h>
#include <string.h>
#include <stdio.h>

refcount_closure<(int) -> int> make_fn(int a) {
  refcount_closure<(int) -> int> fn1 = refcount_lambda (int x) -> (x + a);
  refcount_closure<(int) -> int> fn2 = refcount_lambda (int x) -> (fn1(x * 2) - 1);
  fn1.remove_ref();
  return fn2;
}

int app_fn(refcount_closure<(int) -> int> fn, int a) {
  int result = fn(a);
  fn.remove_ref();
  return result;
}

int main() {
  refcount_closure<(int) -> int> fn = make_fn(3);
  fn.add_ref();
  printf("%d\n", app_fn(fn, 9));
  fn.remove_ref();
}
