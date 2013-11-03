#include <device_matrix.h>
#define mylog(token) {cout << #token " = " << token << endl;}

// ===============================
// ===== class device_matrix =====
// ===============================

template <typename T>
device_matrix<T>::device_matrix(): _rows(0), _cols(0), _data(NULL) { }

template <typename T>
device_matrix<T>::device_matrix(size_t r, size_t c): _rows(r), _cols(c), _data(NULL) {
  _init();
  fillwith(0);
}

template <typename T>
device_matrix<T>::device_matrix(const string& filename): _rows(0), _cols(0), _data(NULL) {

  const size_t MAX_BUFFER = 65536;
  char line[MAX_BUFFER];

  FILE* fid = fopen(filename.c_str(), "r");
  while (fgets(line, MAX_BUFFER, fid)) {
    _rows++;

    if (_cols != 0)
      continue;

    char* token = strtok(line, " \n");
    ++_cols;
    while(strtok(NULL, " \n"))
      ++_cols;
  }
  fseek(fid, 0, SEEK_SET);

  // BEWARE !!
  // BLAS stores data in column-major
  T* data = new T[_rows*_cols];
  for (size_t i=0; i<_rows; ++i)
    for (size_t j=0; j<_cols; ++j)
      fscanf(fid, "%f ", &(data[j*_rows + i]));
  fclose(fid);

  _init();
  CCE(cudaMemcpy(_data, data, sizeof(T) * _rows * _cols, cudaMemcpyHostToDevice));
  delete [] data;
}
// Copy Constructor 
template <typename T>
device_matrix<T>::device_matrix(const device_matrix<T>& source): _rows(source._rows), _cols(source._cols), _data(NULL) {
  _init();
  CCE(cudaMemcpy(_data, source._data, sizeof(T) * _rows * _cols, cudaMemcpyDeviceToDevice));
}

#ifdef HAVE_THRUST_DEVICE_VECTOR_H
// Conversion operator
template <typename T>
device_matrix<T>::operator thrust::device_vector<T>() const {
  assert(_rows == 1 || _cols == 1);
  return thrust::device_vector<T>(_data, _data + size());
}
#endif

template <typename T>
device_matrix<T>::~device_matrix() {
  CCE(cudaFree(_data));
}

// ===========================
// ===== Other Functions =====
// ===========================

// ===== Addition =====
template <typename T>
device_matrix<T>& device_matrix<T>::operator += (T val) {
  CCE(cublasSaxpy(CUBLAS_HANDLE::getInstance(), _rows*_cols, &val, SCALAR_MEMORY_BUFFER<T>::getBuffer(), 0, _data, 1));
  return *this;
} 

template <typename T>
device_matrix<T> device_matrix<T>::operator + (T val) const {
  device_matrix<T> m(*this);
  return (m += val);
}

template <typename T>
device_matrix<T>& device_matrix<T>::operator += (const device_matrix<T>& rhs) {
  *this = *this + rhs;
  return *this;
}

template <typename T>
device_matrix<T> device_matrix<T>::operator + (const device_matrix<T>& rhs) const {
  device_matrix<T> result(_rows, _cols);
  sgeam(*this, rhs, result, 1.0, 1.0);
  return result;
}

// ===== Substraction =====
template <typename T>
device_matrix<T>& device_matrix<T>::operator -= (T val) {
  val = -val;
  CCE(cublasSaxpy(CUBLAS_HANDLE::getInstance(), _rows*_cols, &val, SCALAR_MEMORY_BUFFER<T>::getBuffer(), 0, _data, 1));
  return *this;
}

template <typename T>
device_matrix<T> device_matrix<T>::operator - (T val) const {
  device_matrix<T> m(*this);
  return (m -= val);
}

template <typename T>
device_matrix<T>& device_matrix<T>::operator -= (const device_matrix<T>& rhs) {
  *this = *this - rhs;
  return *this;
}

template <typename T>
device_matrix<T> device_matrix<T>::operator - (const device_matrix<T>& rhs) const {
  device_matrix<T> result(_rows, _cols);
  sgeam(*this, rhs, result, 1.0, -1.0);
  return result;
}

// ===== Division =====
template <typename T>
device_matrix<T>& device_matrix<T>::operator /= (T alpha) {
  return *this *= ( (T) 1 / alpha );
}

template <typename T>
device_matrix<T> device_matrix<T>::operator / (T alpha) const {
  return *this * ( (T) 1 / alpha );
}

// ===== Matrix-scalar Multiplication =====
template <typename T>
device_matrix<T>& device_matrix<T>::operator *= (T alpha) {
  cublasStatus_t status;
  status = cublasSscal(CUBLAS_HANDLE::getInstance(), _rows*_cols, &alpha, _data, STRIDE);
  CCE(status);
  return *this;
}

template <typename T>
device_matrix<T> device_matrix<T>::operator * (T alpha) const {
  device_matrix<T> result(*this);
  return result *= alpha;
}

// ===== Matrix-Matrix Multiplication =====
template <typename T>
device_matrix<T>& device_matrix<T>::operator *= (const device_matrix<T>& rhs) {
  *this = *this * rhs;
  return *this;
}

template <typename T>
device_matrix<T> device_matrix<T>::operator * (const device_matrix<T>& rhs) const {
  device_matrix<T> result(_rows, rhs._cols);
  sgemm(*this, rhs, result);
  return result;
}

// Operator Assignment:
// call copy constructor first, and swap with the temp variable
template <typename T>
device_matrix<T>& device_matrix<T>::operator = (device_matrix<T> rhs) {
  swap(*this, rhs);
  return *this;
}

template <typename T>
void device_matrix<T>::_init() {
  CCE(cudaMalloc((void **)&_data, _rows * _cols * sizeof(T)));
}

template <typename T>
void device_matrix<T>::resize(size_t r, size_t c) {
  if (_rows == r && _cols == c)
    return;

  _rows = r;
  _cols = c;
  _init();
  fillwith(0);
}

template <typename T>
void device_matrix<T>::print(FILE* fid) const {

  T* data = new T[size()];
  CCE(cudaMemcpy(data, _data, sizeof(T) * size(), cudaMemcpyDeviceToHost));

  for (size_t i=0; i<_rows; ++i) {
    for (size_t j=0; j<_cols; ++j)
      fprintf(fid, "%.7f ", data[j*_rows + i]);
    fprintf(fid, "\n");
  }

  if (fid == stdout)
    fprintf(fid, "\n");

  delete [] data;
}

template <typename T>
void device_matrix<T>::fillwith(T val) {
  cudaMemset(_data, 0, _rows * _cols * sizeof(T));
}

template <typename T>
void device_matrix<T>::save(const string& filename) const {
  FILE* fid = fopen(filename.c_str(), "w");
  if (fid == NULL)
    return;

  print(fid);
  fclose(fid);
}

template <>
void device_matrix<float>::cublas_gemm(
  cublasOperation_t transA, cublasOperation_t transB,
  int m, int n, int k,
  float alpha,
  const float* A, int lda,
  const float* B, int ldb,
  float beta,
  float* C, int ldc) {
  CCE(cublasSgemm(CUBLAS_HANDLE::getInstance(), transA, transB, m, n, k, &alpha, A, lda, B, ldb, &beta, C, ldc));
}

template <>
void device_matrix<double>::cublas_gemm(
  cublasOperation_t transA, cublasOperation_t transB,
  int m, int n, int k,
  double alpha,
  const double* A, int lda,
  const double* B, int ldb,
  double beta,
  double* C, int ldc) {
  CCE(cublasDgemm(CUBLAS_HANDLE::getInstance(), transA, transB, m, n, k, &alpha, A, lda, B, ldb, &beta, C, ldc));
}

template <>
void device_matrix<float>::cublas_geam(
    cublasOperation_t transA, cublasOperation_t transB,
    int m, int n,
    float alpha, const float *A, int lda,
    float beta , const float *B, int ldb,
    float *C, int ldc) {
  CCE(cublasSgeam(CUBLAS_HANDLE::getInstance(), transA, transB, m, n, &alpha, A, lda, &beta, B, ldb, C, ldc));
}

template <>
void device_matrix<double>::cublas_geam(
    cublasOperation_t transA, cublasOperation_t transB,
    int m, int n,
    double alpha, const double *A, int lda,
    double beta , const double *B, int ldb,
    double *C, int ldc) {
  CCE(cublasDgeam(CUBLAS_HANDLE::getInstance(), transA, transB, m, n, &alpha, A, lda, &beta, B, ldb, C, ldc));
}

template <>
void device_matrix<float>::cublas_nrm2(int n, const float *x, int incx, float *result) {
  CCE(cublasSnrm2(CUBLAS_HANDLE::getInstance(), n, x, 1, result));
}

template <>
void device_matrix<double>::cublas_nrm2(int n, const double *x, int incx, double *result) {
  CCE(cublasDnrm2(CUBLAS_HANDLE::getInstance(), n, x, 2, result));
}

// ++++++++++++++++++++++++++++++++++++++++++++
// +++++ Template Explicit Initialization +++++
// ++++++++++++++++++++++++++++++++++++++++++++
template class device_matrix<float>;

#define _DSMAT_ device_matrix<float>
float snrm2(const _DSMAT_& A) {
  float result;
  cublasStatus_t status;
  status = cublasSnrm2(CUBLAS_HANDLE::getInstance(), A.size(), A.getData(), 1, &result);
  CCE(status);
  return result;
}

void sgemm(const _DSMAT_& A, const _DSMAT_& B, _DSMAT_& C, float alpha, float beta) {
  // Perform C = αA*B + βC, not transpose on A and B
  size_t m = A.getRows();
  size_t n = B.getCols();
  C.resize(m, n);

  size_t k = A.getCols();

  int lda = A.getRows();
  int ldb = B.getRows();
  int ldc = C.getRows();

  cublasStatus_t status;
  status = cublasSgemm(CUBLAS_HANDLE::getInstance(), CUBLAS_OP_N, CUBLAS_OP_N, m, n, k, &alpha, A.getData(), lda, B.getData(), ldb, &beta, C.getData(), ldc);

  CCE(status);
}

void sgeam(const _DSMAT_& A, const _DSMAT_& B, _DSMAT_& C, float alpha, float beta) {
  // Perform C = αA + βB, not transpose on A and B
  assert(A.getRows() == B.getRows() && A.getCols() == B.getCols());
  
  size_t m = A.getRows();
  size_t n = A.getCols();
  C.resize(m, n);

  int lda = A.getRows();
  int ldb = B.getRows();
  int ldc = C.getRows();

  cublasStatus_t status;
  status = cublasSgeam(CUBLAS_HANDLE::getInstance(), CUBLAS_OP_N, CUBLAS_OP_N, m, n, &alpha, A.getData(), lda, &beta, B.getData(), ldb, C.getData(), ldc);
  CCE(status);
}
#undef _DSMAT_

