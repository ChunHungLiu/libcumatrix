#include <iostream>
#include <color.h>

#include <device_matrix.h>

using namespace std;

typedef device_matrix<float> mat;

struct Timer {
  Timer() {
    CCE(cudaEventCreate(&start));
    CCE(cudaEventCreate(&stop));
  }

  void tic() {
    CCE(cudaEventRecord(start, NULL));
  }

  float toc() {
    CCE(cudaEventRecord(stop, NULL));
    CCE(cudaEventSynchronize(stop));

    float diff = 0.0f;
    CCE(cudaEventElapsedTime(&diff , start, stop));
  }

  cudaEvent_t start, stop;
};

void showGFlops(double flops, float time) {
  double gigaFlops = (flops * 1.0e-9f) / (time / 1000.0f);
  printf("Performance= %.2f GFlop/s, Time= %.3f msec, Size= %.0f Ops\n", gigaFlops, time, flops);
}

void compareL2error();
void benchmark();

int main (int argc, char* argv[]) {

  compareL2error();
  benchmark();
  // mat inv("data/inv_x.mat");
  // mat L("data/L.mat");
  // mat U("data/U.mat");

  return 0;
}

void compareL2error() {

  mat A("data/A.mat");
  mat B("data/B.mat");
  mat C("data/C.mat");

  float error = snrm2(C - A*B) / snrm2(C);
  printf("error = %.7e \n", error);

}

void benchmark() {

  mat A("data/A.mat");
  mat B("data/B.mat");
  mat C;

  Timer timer;
  timer.tic();

  int nIter = 128;
  for (int i=0; i<nIter; ++i)
    sgemm(A, B, C);

  float avgTime = timer.toc() / nIter;
  double flops = 2.0 * (double) A.getRows() * (double) A.getCols() * (double) B.getCols();
  showGFlops(flops, avgTime);

  Timer timer2;
  timer2.tic();
  for (int i=0; i<nIter; ++i)
    mat C(A * B);

  avgTime = timer2.toc() / nIter;
  showGFlops(flops, avgTime);
}
