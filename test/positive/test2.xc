#include <refcount.h>
#include <string.h>
#include <stdio.h>

int main() {
  refcount_tag x_rt;
  float *x_p = refcount_malloc(sizeof(float), &x_rt);
  closure<(int) -> void> fn = lambda [x_rt, x_p](int i) -> (void) { *x_p = i / 2.0; };
  remove_ref(x_rt);
  
  fn(37);
  float x = *x_p;
  
  fn.remove_ref();
  
  printf("%f\n", x);
  return x != 18.5;
}
