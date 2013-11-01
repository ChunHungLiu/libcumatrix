#include <iostream>
#include <matrix.h>

#include <device_matrix.h>
#include <device_math_ext.h>
#include <device_arithmetic.h>
#define TEST_CL2E(x, y) {printf("checking "#x" ... "); compareL2error((x), (y));}

using namespace std;

typedef device_matrix<float> mat;
typedef thrust::device_vector<float> vec;

void testing();
void checkErrorIsAcceptable(double err);
void compareL2error(const vec& v, const vec& ref);
void compareL2error(const mat& m, const mat& ref);

int main (int argc, char* argv[]) {
  testing();
  return 0;
}

void testing() {
  mat A("data/A.mat");
  mat B("data/B.mat");
  mat C("data/C.mat");
  mat D("data/D.mat");

  vec x = ext::load<float>("data/x.vec");
  vec y = ext::load<float>("data/y.vec");
  vec u = ext::load<float>("data/u.vec");
  vec v = ext::load<float>("data/v.vec");

  mat ApB("data/A+B.mat");
  mat AmB("data/A-B.mat");
  mat CmD("data/C-D.mat");
  mat CpD("data/C+D.mat");

  mat AC("data/AC.mat");
  mat AD("data/AD.mat");
  mat BC("data/BC.mat");
  mat BD("data/BD.mat");

  vec Ax = ext::load<float>("data/Ax.vec");
  vec Bx = ext::load<float>("data/Bx.vec");
  vec Cy = ext::load<float>("data/Cy.vec");
  vec Dy = ext::load<float>("data/Dy.vec");

  vec uA = ext::load<float>("data/uA.vec");
  vec uB = ext::load<float>("data/uB.vec");
  vec vC = ext::load<float>("data/vC.vec");
  vec vD = ext::load<float>("data/vD.vec");

  mat PIpA("data/pi+A.mat");
  mat PImB("data/pi-B.mat");
  mat eC("data/eC.mat");
  mat D_over_e("data/D_over_e.mat");

  mat uAx("data/uAx.scalar");
  mat uBx("data/uBx.scalar");
  mat vCy("data/vCy.scalar");
  mat vDy("data/vDy.scalar");

  mat xu("data/xu.mat");
  mat xv("data/xv.mat");
  mat yu("data/yu.mat");
  mat yv("data/yv.mat");

  printf("A : %lu by %lu \n", A.getRows(), A.getCols());
  printf("A : %lu by %lu \n", C.getRows(), C.getCols());
  printf("AC: %lu by %lu \n", AC.getRows(), AC.getCols());

  printf("\n===== FILE I/O Testing =====\n");
  A.save("/tmp/cumatrix.mat");
  TEST_CL2E(mat("/tmp/cumatrix.mat"), A)

  printf("\n===== Matrix Addition =====\n");
  TEST_CL2E(A + B, ApB);
  TEST_CL2E(A - B, AmB);
  TEST_CL2E(C + D, CpD);
  TEST_CL2E(C - D, CmD);

  printf("\n===== Matrix - Matrix Multiplication =====\n");
  TEST_CL2E(A * C, AC);
  TEST_CL2E(A * D, AD);
  TEST_CL2E(B * C, BC);
  TEST_CL2E(B * D, BD);

  printf("\n===== Matrix - Vector Multiplication =====\n");
  TEST_CL2E(A * x, Ax);
  TEST_CL2E(B * x, Bx);
  TEST_CL2E(C * y, Cy);
  TEST_CL2E(D * y, Dy);

  TEST_CL2E(u * A, uA);
  TEST_CL2E(u * B, uB);
  TEST_CL2E(v * C, vC);
  TEST_CL2E(v * D, vD);

  printf("\n===== Matrix - Scalar Arithmetic =====\n");
  TEST_CL2E(A + PI, PIpA);
  // TEST_CL2E(PI - B, PImB);
  TEST_CL2E(2.718281828f * C, eC);
  TEST_CL2E(D / 2.718281828f, D_over_e);
}

void compareL2error(const mat& m, const mat& ref) {
  float error = snrm2(m - ref) / snrm2(ref);
  checkErrorIsAcceptable(error);
}

void compareL2error(const vec& v, const vec& ref) {
  float error = norm(v - ref) / norm(ref);
  checkErrorIsAcceptable(error);
}

void checkErrorIsAcceptable(double error) {
  const float EPS = 1e-6;
  if (error < EPS)
    printf("\33[32m[ OK ]\33[0m \n");
  else
    printf("error = %.4e > EPS (%.4e) \33[31m[FAILED]\33[0m\n", error, EPS);
}
