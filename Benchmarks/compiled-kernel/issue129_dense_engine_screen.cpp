#include <Accelerate/Accelerate.h>
#include <dlfcn.h>
#include <fftw3.h>
#include <pffft/pffft_double.h>

#include <algorithm>
#include <chrono>
#include <cmath>
#include <complex>
#include <condition_variable>
#include <cstddef>
#include <cstdint>
#include <fstream>
#include <functional>
#include <iomanip>
#include <iostream>
#include <limits>
#include <memory>
#include <mutex>
#include <random>
#include <stdexcept>
#include <string>
#include <thread>
#include <utility>
#include <vector>

namespace {

using Clock = std::chrono::steady_clock;
using Complex = std::complex<double>;

struct Options {
    std::size_t Nx = 0;
    std::size_t Ny = 0;
    std::size_t planes = 0;
    std::size_t workers = 1;
    std::size_t warmups = 1;
    std::size_t samples = 3;
    std::uint64_t seed = 129;
    std::string output;
};

struct EngineResult {
    std::string id;
    std::string identity;
    std::string vectorPath;
    double planningSeconds = 0.0;
    std::size_t workspaceBytes = 0;
    std::vector<double> forwardSeconds;
    std::vector<double> inverseSeconds;
    double forwardRelativeError = 0.0;
    double inverseRelativeError = 0.0;
};

std::size_t checkedProduct(std::size_t a, std::size_t b) {
    if (a != 0 && b > std::numeric_limits<std::size_t>::max()/a) throw std::overflow_error("Size overflow.");
    return a*b;
}

double elapsed(const Clock::time_point& start) {
    return std::chrono::duration<double>(Clock::now()-start).count();
}

std::string libraryContaining(const void* symbol) {
    Dl_info info{};
    return symbol != nullptr && dladdr(symbol,&info) != 0 && info.dli_fname != nullptr ? info.dli_fname : "";
}

class PlaneExecutor {
public:
    PlaneExecutor(std::size_t planes,std::size_t requestedWorkers) : planes_(planes), workerCount_(std::max<std::size_t>(1,std::min(planes,requestedWorkers))) {
        threads_.reserve(workerCount_-1);
        for (std::size_t worker=1;worker<workerCount_;++worker) threads_.emplace_back([this,worker]{workerLoop(worker);});
    }
    ~PlaneExecutor() {
        { std::lock_guard<std::mutex> lock(mutex_); stopping_=true; ++generation_; }
        start_.notify_all();
        for(auto& thread:threads_) thread.join();
    }
    PlaneExecutor(const PlaneExecutor&)=delete;
    PlaneExecutor& operator=(const PlaneExecutor&)=delete;
    void run(std::function<void(std::size_t,std::size_t,std::size_t)> task) {
        if(workerCount_==1){task(0,0,planes_);return;}
        { std::lock_guard<std::mutex> lock(mutex_); task_=std::move(task); remaining_=workerCount_-1; ++generation_; }
        start_.notify_all();
        task_(0,0,planes_/workerCount_);
        std::unique_lock<std::mutex> lock(mutex_); done_.wait(lock,[this]{return remaining_==0;}); task_={};
    }
    std::size_t workerCount() const noexcept{return workerCount_;}
private:
    void workerLoop(std::size_t worker) {
        std::size_t observed=0;
        for(;;){
            std::function<void(std::size_t,std::size_t,std::size_t)> task;
            { std::unique_lock<std::mutex> lock(mutex_); start_.wait(lock,[&]{return stopping_||generation_!=observed;}); if(stopping_)return; observed=generation_; task=task_; }
            task(worker,planes_*worker/workerCount_,planes_*(worker+1)/workerCount_);
            { std::lock_guard<std::mutex> lock(mutex_); if(--remaining_==0)done_.notify_one(); }
        }
    }
    std::size_t planes_=0,workerCount_=1,generation_=0,remaining_=0;
    bool stopping_=false;
    std::mutex mutex_;
    std::condition_variable start_,done_;
    std::function<void(std::size_t,std::size_t,std::size_t)> task_;
    std::vector<std::thread> threads_;
};

class AlignedDoubles {
public:
    explicit AlignedDoubles(std::size_t count = 0) : count_(count), data_(count == 0 ? nullptr : static_cast<double*>(pffftd_aligned_malloc(count*sizeof(double)))) {
        if (count != 0 && data_ == nullptr) throw std::bad_alloc();
    }
    ~AlignedDoubles() { pffftd_aligned_free(data_); }
    AlignedDoubles(const AlignedDoubles&) = delete;
    AlignedDoubles& operator=(const AlignedDoubles&) = delete;
    AlignedDoubles(AlignedDoubles&& other) noexcept : count_(std::exchange(other.count_,0)), data_(std::exchange(other.data_,nullptr)) {}
    double* data() noexcept { return data_; }
    const double* data() const noexcept { return data_; }
    std::size_t bytes() const noexcept { return count_*sizeof(double); }
private:
    std::size_t count_ = 0;
    double* data_ = nullptr;
};

class FFTWPipeline {
public:
    explicit FFTWPipeline(const Options& options) : options_(options) {
        const auto start = Clock::now();
        if (fftw_init_threads() == 0) throw std::runtime_error("fftw_init_threads failed.");
        fftw_plan_with_nthreads(static_cast<int>(options.workers));
        fftw_iodim64 forwardDimensions[2] = {
            {static_cast<ptrdiff_t>(options.Ny),static_cast<ptrdiff_t>(options.Nx),static_cast<ptrdiff_t>(options.Nx/2+1)},
            {static_cast<ptrdiff_t>(options.Nx),1,1}};
        fftw_iodim64 inverseDimensions[2] = {
            {static_cast<ptrdiff_t>(options.Ny),static_cast<ptrdiff_t>(options.Nx/2+1),static_cast<ptrdiff_t>(options.Nx)},
            {static_cast<ptrdiff_t>(options.Nx),1,1}};
        fftw_iodim64 forwardBatches[1] = {{static_cast<ptrdiff_t>(options.planes),static_cast<ptrdiff_t>(options.Nx*options.Ny),static_cast<ptrdiff_t>((options.Nx/2+1)*options.Ny)}};
        fftw_iodim64 inverseBatches[1] = {{static_cast<ptrdiff_t>(options.planes),static_cast<ptrdiff_t>((options.Nx/2+1)*options.Ny),static_cast<ptrdiff_t>(options.Nx*options.Ny)}};
        const auto realBytes = options.Nx*options.Ny*options.planes*sizeof(double);
        const auto complexBytes = (options.Nx/2+1)*options.Ny*options.planes*sizeof(Complex);
        auto* realSurrogate = static_cast<double*>(fftw_malloc(realBytes));
        auto* complexSurrogate = static_cast<fftw_complex*>(fftw_malloc(complexBytes));
        if (realSurrogate == nullptr || complexSurrogate == nullptr) {
            fftw_free(realSurrogate); fftw_free(complexSurrogate); throw std::bad_alloc();
        }
        forward_ = fftw_plan_guru64_dft_r2c(2,forwardDimensions,1,forwardBatches,realSurrogate,complexSurrogate,FFTW_MEASURE | FFTW_UNALIGNED);
        inverse_ = fftw_plan_guru64_dft_c2r(2,inverseDimensions,1,inverseBatches,complexSurrogate,realSurrogate,FFTW_MEASURE | FFTW_UNALIGNED);
        fftw_free(realSurrogate); fftw_free(complexSurrogate);
        if (forward_ == nullptr || inverse_ == nullptr) throw std::runtime_error("FFTW could not create the batched plans.");
        planningSeconds = elapsed(start);
    }
    ~FFTWPipeline() {
        if (forward_ != nullptr) fftw_destroy_plan(forward_);
        if (inverse_ != nullptr) fftw_destroy_plan(inverse_);
    }
    void forward(const double* input, Complex* output) { fftw_execute_dft_r2c(forward_,const_cast<double*>(input),reinterpret_cast<fftw_complex*>(output)); }
    void inverse(Complex* input, double* output) { fftw_execute_dft_c2r(inverse_,reinterpret_cast<fftw_complex*>(input),output); }
    double planningSeconds = 0.0;
private:
    Options options_;
    fftw_plan forward_ = nullptr;
    fftw_plan inverse_ = nullptr;
};

struct PFFFTWorker {
    PFFFTWorker(std::size_t Nx, std::size_t Ny) : realInput(Nx), realOutput(Nx), realWork(Nx), complexInput(2*Ny), complexOutput(2*Ny), complexWork(2*Ny), plane((Nx/2+1)*Ny) {}
    std::size_t bytes() const { return realInput.bytes()+realOutput.bytes()+realWork.bytes()+complexInput.bytes()+complexOutput.bytes()+complexWork.bytes()+plane.size()*sizeof(Complex); }
    AlignedDoubles realInput,realOutput,realWork,complexInput,complexOutput,complexWork;
    std::vector<Complex> plane;
};

class PFFFTPipeline {
public:
    explicit PFFFTPipeline(const Options& options) : options_(options),executor_(options.planes,options.workers) {
        const auto start = Clock::now();
        real_ = pffftd_new_setup(static_cast<int>(options.Nx),PFFFT_REAL);
        complex_ = pffftd_new_setup(static_cast<int>(options.Ny),PFFFT_COMPLEX);
        if (real_ == nullptr || complex_ == nullptr) throw std::runtime_error("PFFFT rejected the requested transform sizes.");
        const auto workers = executor_.workerCount();
        scratch_.reserve(workers);
        for (std::size_t i = 0; i < workers; ++i) scratch_.push_back(std::make_unique<PFFFTWorker>(options.Nx,options.Ny));
        planningSeconds = elapsed(start);
    }
    ~PFFFTPipeline() {
        if (real_ != nullptr) pffftd_destroy_setup(real_);
        if (complex_ != nullptr) pffftd_destroy_setup(complex_);
    }
    std::size_t workspaceBytes() const {
        std::size_t total = 0;
        for (const auto& worker : scratch_) total += worker->bytes();
        return total;
    }
    void forward(const double* input, Complex* output) {
        const auto Nx = options_.Nx, Ny = options_.Ny, NxHalf = Nx/2+1;
        executor_.run([&](std::size_t workerIndex,std::size_t begin,std::size_t end) {
            auto& w = *scratch_[workerIndex];
            for (std::size_t plane = begin; plane < end; ++plane) {
                const double* source = input + plane*Nx*Ny;
                Complex* destination = output + plane*NxHalf*Ny;
                for (std::size_t y = 0; y < Ny; ++y) {
                    std::copy_n(source+y*Nx,Nx,w.realInput.data());
                    pffftd_transform_ordered(real_,w.realInput.data(),w.realOutput.data(),w.realWork.data(),PFFFT_FORWARD);
                    w.plane[NxHalf*y] = {w.realOutput.data()[0],0.0};
                    for (std::size_t x = 1; x+1 < NxHalf; ++x) w.plane[x+NxHalf*y] = {w.realOutput.data()[2*x],w.realOutput.data()[2*x+1]};
                    w.plane[NxHalf-1+NxHalf*y] = {w.realOutput.data()[1],0.0};
                }
                for (std::size_t x = 0; x < NxHalf; ++x) {
                    for (std::size_t y = 0; y < Ny; ++y) {
                        const auto value = w.plane[x+NxHalf*y];
                        w.complexInput.data()[2*y] = value.real();
                        w.complexInput.data()[2*y+1] = value.imag();
                    }
                    pffftd_transform_ordered(complex_,w.complexInput.data(),w.complexOutput.data(),w.complexWork.data(),PFFFT_FORWARD);
                    for (std::size_t y = 0; y < Ny; ++y) destination[x+NxHalf*y] = {w.complexOutput.data()[2*y],w.complexOutput.data()[2*y+1]};
                }
            }
        });
    }
    void inverse(const Complex* input, double* output) {
        const auto Nx = options_.Nx, Ny = options_.Ny, NxHalf = Nx/2+1;
        executor_.run([&](std::size_t workerIndex,std::size_t begin,std::size_t end) {
            auto& w = *scratch_[workerIndex];
            for (std::size_t plane = begin; plane < end; ++plane) {
                const Complex* source = input + plane*NxHalf*Ny;
                double* destination = output + plane*Nx*Ny;
                for (std::size_t x = 0; x < NxHalf; ++x) {
                    for (std::size_t y = 0; y < Ny; ++y) {
                        const auto value = source[x+NxHalf*y];
                        w.complexInput.data()[2*y] = value.real();
                        w.complexInput.data()[2*y+1] = value.imag();
                    }
                    pffftd_transform_ordered(complex_,w.complexInput.data(),w.complexOutput.data(),w.complexWork.data(),PFFFT_BACKWARD);
                    for (std::size_t y = 0; y < Ny; ++y) w.plane[x+NxHalf*y] = {w.complexOutput.data()[2*y],w.complexOutput.data()[2*y+1]};
                }
                for (std::size_t y = 0; y < Ny; ++y) {
                    w.realInput.data()[0] = w.plane[NxHalf*y].real();
                    w.realInput.data()[1] = w.plane[NxHalf-1+NxHalf*y].real();
                    for (std::size_t x = 1; x+1 < NxHalf; ++x) {
                        const auto value = w.plane[x+NxHalf*y];
                        w.realInput.data()[2*x] = value.real();
                        w.realInput.data()[2*x+1] = value.imag();
                    }
                    pffftd_transform_ordered(real_,w.realInput.data(),w.realOutput.data(),w.realWork.data(),PFFFT_BACKWARD);
                    std::copy_n(w.realOutput.data(),Nx,destination+y*Nx);
                }
            }
        });
    }
    double planningSeconds = 0.0;
private:
    Options options_;
    PlaneExecutor executor_;
    PFFFTD_Setup* real_ = nullptr;
    PFFFTD_Setup* complex_ = nullptr;
    std::vector<std::unique_ptr<PFFFTWorker>> scratch_;
};

struct VDSPWorker {
    VDSPWorker(std::size_t Nx, std::size_t Ny) : real((Nx/2)*Ny), imag((Nx/2)*Ny) {
        std::size_t maximum = std::max(Nx,Ny);
        setup = vDSP_create_fftsetupD(static_cast<vDSP_Length>(std::log2(maximum)),kFFTRadix2);
        if (setup == nullptr) throw std::runtime_error("vDSP setup creation failed.");
    }
    ~VDSPWorker() { if (setup != nullptr) vDSP_destroy_fftsetupD(setup); }
    std::size_t bytes() const { return (real.size()+imag.size())*sizeof(double); }
    FFTSetupD setup = nullptr;
    std::vector<double> real,imag;
};

class VDSPPipeline {
public:
    explicit VDSPPipeline(const Options& options) : options_(options),executor_(options.planes,options.workers) {
        const auto start = Clock::now();
        const auto workers = executor_.workerCount();
        scratch_.reserve(workers);
        for (std::size_t i = 0; i < workers; ++i) scratch_.push_back(std::make_unique<VDSPWorker>(options.Nx,options.Ny));
        planningSeconds = elapsed(start);
    }
    std::size_t workspaceBytes() const {
        std::size_t total = 0;
        for (const auto& worker : scratch_) total += worker->bytes();
        return total;
    }
    void forward(const double* input, Complex* output) {
        const auto Nx = options_.Nx, Ny = options_.Ny, half = Nx/2, NxHalf = half+1;
        executor_.run([&](std::size_t workerIndex,std::size_t begin,std::size_t end) {
            auto& w = *scratch_[workerIndex];
            DSPDoubleSplitComplex split{w.real.data(),w.imag.data()};
            for (std::size_t plane = begin; plane < end; ++plane) {
                const double* source = input+plane*Nx*Ny;
                Complex* destination = output+plane*NxHalf*Ny;
                for (std::size_t y = 0; y < Ny; ++y) for (std::size_t x = 0; x < half; ++x) {
                    const auto packed = y*half+x;
                    w.real[packed] = source[y*Nx+2*x];
                    w.imag[packed] = source[y*Nx+2*x+1];
                }
                vDSP_fft2d_zripD(w.setup,&split,1,static_cast<vDSP_Stride>(half),log2Length(Nx),log2Length(Ny),FFT_FORWARD);
                unpackForward(w,destination);
            }
        });
    }
    void inverse(const Complex* input, double* output) {
        const auto Nx = options_.Nx, Ny = options_.Ny, half = Nx/2, NxHalf = half+1;
        executor_.run([&](std::size_t workerIndex,std::size_t begin,std::size_t end) {
            auto& w = *scratch_[workerIndex];
            DSPDoubleSplitComplex split{w.real.data(),w.imag.data()};
            for (std::size_t plane = begin; plane < end; ++plane) {
                const Complex* source = input+plane*NxHalf*Ny;
                double* destination = output+plane*Nx*Ny;
                packInverse(source,w);
                vDSP_fft2d_zripD(w.setup,&split,1,static_cast<vDSP_Stride>(half),log2Length(Nx),log2Length(Ny),FFT_INVERSE);
                for (std::size_t y = 0; y < Ny; ++y) for (std::size_t x = 0; x < half; ++x) {
                    const auto packed = y*half+x;
                    destination[y*Nx+2*x] = w.real[packed];
                    destination[y*Nx+2*x+1] = w.imag[packed];
                }
            }
        });
    }
    double planningSeconds = 0.0;
private:
    static vDSP_Length log2Length(std::size_t value) {
        if (value == 0 || (value&(value-1)) != 0) throw std::runtime_error("vDSP requires power-of-two lengths.");
        vDSP_Length result = 0; while ((std::size_t{1}<<result) < value) ++result; return result;
    }
    void unpackForward(VDSPWorker& w, Complex* output) {
        const auto Nx = options_.Nx, Ny = options_.Ny, half = Nx/2, NxHalf = half+1;
        for (std::size_t y = 0; y < Ny; ++y) for (std::size_t x = 1; x < half; ++x) output[x+NxHalf*y] = 0.5*Complex{w.real[y*half+x],w.imag[y*half+x]};
        output[0] = {0.5*w.real[0],0.0};
        output[half] = {0.5*w.imag[0],0.0};
        const std::size_t yNyquist = Ny/2;
        output[NxHalf*yNyquist] = {0.5*w.real[half],0.0};
        output[half+NxHalf*yNyquist] = {0.5*w.imag[half],0.0};
        for (std::size_t y = 1; y < yNyquist; ++y) {
            const auto first = (2*y)*half, second = (2*y+1)*half;
            const Complex zero = 0.5*Complex{w.real[first],w.real[second]};
            const Complex nyquist = 0.5*Complex{w.imag[first],w.imag[second]};
            output[NxHalf*y] = zero; output[NxHalf*(Ny-y)] = std::conj(zero);
            output[half+NxHalf*y] = nyquist; output[half+NxHalf*(Ny-y)] = std::conj(nyquist);
        }
    }
    void packInverse(const Complex* input, VDSPWorker& w) {
        const auto Nx = options_.Nx, Ny = options_.Ny, half = Nx/2, NxHalf = half+1;
        std::fill(w.real.begin(),w.real.end(),0.0); std::fill(w.imag.begin(),w.imag.end(),0.0);
        for (std::size_t y = 0; y < Ny; ++y) for (std::size_t x = 1; x < half; ++x) { const auto value=input[x+NxHalf*y]; w.real[y*half+x]=value.real(); w.imag[y*half+x]=value.imag(); }
        w.real[0]=input[0].real(); w.imag[0]=input[half].real();
        const std::size_t yNyquist=Ny/2;
        w.real[half]=input[NxHalf*yNyquist].real(); w.imag[half]=input[half+NxHalf*yNyquist].real();
        for (std::size_t y=1; y<yNyquist; ++y) { const auto zero=input[NxHalf*y], nyquist=input[half+NxHalf*y]; const auto first=(2*y)*half,second=(2*y+1)*half; w.real[first]=zero.real(); w.real[second]=zero.imag(); w.imag[first]=nyquist.real(); w.imag[second]=nyquist.imag(); }
    }
    Options options_;
    PlaneExecutor executor_;
    std::vector<std::unique_ptr<VDSPWorker>> scratch_;
};

double relativeError(const Complex* actual, const Complex* expected, std::size_t count) {
    double numerator=0.0,denominator=0.0;
    for (std::size_t i=0;i<count;++i) { numerator=std::max(numerator,std::abs(actual[i]-expected[i])); denominator=std::max(denominator,std::abs(expected[i])); }
    return numerator/std::max(denominator,std::numeric_limits<double>::min());
}

double relativeErrorScaled(const double* actual, const double* expected, std::size_t count, double scale) {
    double numerator=0.0,denominator=0.0;
    for (std::size_t i=0;i<count;++i) { numerator=std::max(numerator,std::abs(actual[i]*scale-expected[i])); denominator=std::max(denominator,std::abs(expected[i])); }
    return numerator/std::max(denominator,std::numeric_limits<double>::min());
}

template<class Pipeline>
void measureEngine(const std::string& id, const std::string& identity, const std::string& vectorPath, Pipeline& pipeline, const Options& options, const std::vector<double>& input, const std::vector<Complex>& referenceSpectrum, std::vector<Complex>& spectrum, std::vector<double>& output, EngineResult& result) {
    result.id=id; result.identity=identity; result.vectorPath=vectorPath; result.planningSeconds=pipeline.planningSeconds; result.workspaceBytes=pipeline.workspaceBytes();
    for (std::size_t i=0;i<options.warmups;++i) { pipeline.forward(input.data(),spectrum.data()); pipeline.inverse(spectrum.data(),output.data()); }
    pipeline.forward(input.data(),spectrum.data()); result.forwardRelativeError=relativeError(spectrum.data(),referenceSpectrum.data(),spectrum.size());
    pipeline.inverse(referenceSpectrum.data(),output.data()); result.inverseRelativeError=relativeErrorScaled(output.data(),input.data(),input.size(),1.0/static_cast<double>(options.Nx*options.Ny));
    for (std::size_t sample=0;sample<options.samples;++sample) {
        auto start=Clock::now(); pipeline.forward(input.data(),spectrum.data()); result.forwardSeconds.push_back(elapsed(start));
        start=Clock::now(); pipeline.inverse(referenceSpectrum.data(),output.data()); result.inverseSeconds.push_back(elapsed(start));
    }
}

std::string jsonEscape(const std::string& value) {
    std::string output; output.reserve(value.size()+8);
    for(char c:value) { if(c=='\\'||c=='\"') output.push_back('\\'); if(c=='\n'){output += "\\n"; continue;} output.push_back(c); }
    return output;
}

void writeArray(std::ostream& stream,const std::vector<double>& values) {
    stream << '['; for(std::size_t i=0;i<values.size();++i){if(i)stream<<',';stream<<std::setprecision(17)<<values[i];} stream<<']';
}

void writeResult(const Options& options,const std::vector<EngineResult>& results,std::size_t realElements,std::size_t halfElements,double fftwPlanningSeconds) {
    std::ofstream stream(options.output); if(!stream) throw std::runtime_error("Unable to open output JSON.");
    stream << "{\n\"schemaVersion\":\"1.0.0\",\"Nx\":"<<options.Nx<<",\"Ny\":"<<options.Ny<<",\"planes\":"<<options.planes<<",\"workers\":"<<options.workers<<",\"warmups\":"<<options.warmups<<",\"samples\":"<<options.samples<<",\"seed\":"<<options.seed<<",\"realBytes\":"<<realElements*sizeof(double)<<",\"halfSpectrumBytes\":"<<halfElements*sizeof(Complex)<<",\"fftwPlanningSeconds\":"<<std::setprecision(17)<<fftwPlanningSeconds<<",\"engines\":[";
    for(std::size_t i=0;i<results.size();++i){const auto&r=results[i];if(i)stream<<',';stream<<"{\"id\":\""<<jsonEscape(r.id)<<"\",\"identity\":\""<<jsonEscape(r.identity)<<"\",\"vectorPath\":\""<<jsonEscape(r.vectorPath)<<"\",\"planningSeconds\":"<<r.planningSeconds<<",\"workspaceBytes\":"<<r.workspaceBytes<<",\"forwardRelativeError\":"<<r.forwardRelativeError<<",\"inverseRelativeError\":"<<r.inverseRelativeError<<",\"forwardSeconds\":";writeArray(stream,r.forwardSeconds);stream<<",\"inverseSeconds\":";writeArray(stream,r.inverseSeconds);stream<<'}';}
    stream << "]}\n";
}

Options parse(int argc,char** argv) {
    Options options;
    for(int i=1;i+1<argc;i+=2){const std::string key=argv[i],value=argv[i+1];if(key=="--nx")options.Nx=std::stoull(value);else if(key=="--ny")options.Ny=std::stoull(value);else if(key=="--planes")options.planes=std::stoull(value);else if(key=="--workers")options.workers=std::stoull(value);else if(key=="--warmups")options.warmups=std::stoull(value);else if(key=="--samples")options.samples=std::stoull(value);else if(key=="--seed")options.seed=std::stoull(value);else if(key=="--output")options.output=value;else throw std::runtime_error("Unknown argument: "+key);}
    if(options.Nx==0||options.Ny==0||options.planes==0||options.workers==0||options.samples==0||options.output.empty())throw std::runtime_error("Incomplete arguments.");
    return options;
}

} // namespace

int main(int argc,char** argv) {
    try {
        const auto options=parse(argc,argv);
        const auto realElements=checkedProduct(checkedProduct(options.Nx,options.Ny),options.planes);
        const auto halfElements=checkedProduct(checkedProduct(options.Nx/2+1,options.Ny),options.planes);
        std::vector<double> input(realElements),output(realElements),fftwOutput(realElements);
        std::vector<Complex> referenceSpectrum(halfElements),spectrum(halfElements),fftwInverseInput(halfElements);
        std::mt19937_64 generator(options.seed); std::normal_distribution<double> distribution;
        for(auto& value:input)value=distribution(generator);
        FFTWPipeline fftw(options);
        fftw.forward(input.data(),referenceSpectrum.data());
        fftwInverseInput=referenceSpectrum; fftw.inverse(fftwInverseInput.data(),fftwOutput.data());
        std::vector<EngineResult> results;
        EngineResult fftwResult; fftwResult.id="native-fftw"; fftwResult.identity=libraryContaining(reinterpret_cast<const void*>(&fftw_execute)); fftwResult.vectorPath="FFTW 3.3.11 NEON/pthreads"; fftwResult.planningSeconds=fftw.planningSeconds; fftwResult.workspaceBytes=0; fftwResult.forwardRelativeError=0.0; fftwResult.inverseRelativeError=relativeErrorScaled(fftwOutput.data(),input.data(),input.size(),1.0/static_cast<double>(options.Nx*options.Ny));
        for(std::size_t i=0;i<options.warmups;++i){fftw.forward(input.data(),spectrum.data());fftwInverseInput=referenceSpectrum;fftw.inverse(fftwInverseInput.data(),output.data());}
        for(std::size_t sample=0;sample<options.samples;++sample){auto start=Clock::now();fftw.forward(input.data(),spectrum.data());fftwResult.forwardSeconds.push_back(elapsed(start));fftwInverseInput=referenceSpectrum;start=Clock::now();fftw.inverse(fftwInverseInput.data(),output.data());fftwResult.inverseSeconds.push_back(elapsed(start));}
        results.push_back(std::move(fftwResult));
        PFFFTPipeline pffft(options); EngineResult pffftResult; measureEngine("pffft","marton78/pffft@a4b03590cc2a4bea56f9721996e3057835799179",pffftd_simd_arch(),pffft,options,input,referenceSpectrum,spectrum,output,pffftResult); results.push_back(std::move(pffftResult));
        VDSPPipeline vdsp(options); EngineResult vdspResult; measureEngine("accelerate-vdsp",libraryContaining(reinterpret_cast<const void*>(&vDSP_fft2d_zripD)),"vDSP double split-complex 2-D radix-2",vdsp,options,input,referenceSpectrum,spectrum,output,vdspResult); results.push_back(std::move(vdspResult));
        writeResult(options,results,realElements,halfElements,fftw.planningSeconds);
        return 0;
    } catch(const std::exception& error) { std::cerr<<error.what()<<'\n'; return 1; }
}
