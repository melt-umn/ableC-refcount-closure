#include <refcount.h>
#include <string.h>
#include <stdio.h>

void print_addr(void *p) {
  printf("Finalizing address %p\n", p);
}

int main() {
  refcount_tag_t x_rt;
  float *x_p = refcount_final_malloc(sizeof(float), &x_rt, 0, NULL, print_addr);
  closure<(int) -> void> fn = lambda [x_rt, x_p](int i) -> (void) { *x_p = i / 2.0; };
  remove_ref(x_rt);
  
  fn(37);
  float x = *x_p;
  
  fn.remove_ref();
  
  printf("%f\n", x);
}
