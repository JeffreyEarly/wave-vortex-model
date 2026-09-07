#include "WVPreparedModeExecutor.hpp"
#include "WVAllocationProbe.hpp"
#include <array>
#include <iostream>
#include <system_error>

using wavevortex::kernel_detail::WVPreparedModeExecutor;
void require(bool condition, const char* message) {
    if (!condition) throw std::runtime_error(message);
}

int main() {
    try {
        for (std::size_t workers : {1, 2, 5}) {
            std::atomic<int> launches{0}, alive{0};
            {
                WVPreparedModeExecutor executor(workers, [&](auto work) {
                    ++launches;
                    return std::thread([&, work] { ++alive; work(); --alive; });
                });
                std::array<std::atomic<int>, 41> visits{};
                for (auto& value : visits) value = 0;
                allocationProbe::calls = 0;
                allocationProbe::counting = true;
                for (int round = 0; round < 100; ++round) {
                    executor.execute(visits.size(), [&](auto begin, auto end) {
                        for (auto i = begin; i < end; ++i) ++visits[i];
                    });
                    executor.execute(0, [](auto begin, auto end) { require(begin == end, "empty partition"); });
                    executor.execute(1, [](auto begin, auto end) { require(begin <= end && end <= 1, "small partition"); });
                }
                allocationProbe::counting = false;
                require(allocationProbe::calls == 0, "dispatch allocated");
                require(launches == static_cast<int>(workers - 1), "dispatch launched threads");
                for (auto& value : visits) require(value == 100, "partition missed or duplicated work");
                for (bool callerThrows : {true, false}) {
                    std::atomic<int> finished{0};
                    bool caught = false;
                    try {
                        executor.execute(20, [&](auto begin, auto) {
                            ++finished;
                            if ((begin == 0) == callerThrows || workers == 1) throw 42;
                        });
                    } catch (int value) { caught = value == 42; }
                    require(caught && finished == static_cast<int>(workers), "exception escaped before joining work");
                    executor.execute(2, [](auto, auto) {});
                }
            }
            require(alive == 0, "executor left workers alive");
        }
        for (int failureIndex : {0, 1, 3}) {
            std::atomic<int> alive{0};
            int launched = 0;
            bool caught = false;
            try {
                WVPreparedModeExecutor executor(5, [&](auto work) {
                    if (launched == failureIndex) throw std::system_error(std::make_error_code(std::errc::resource_unavailable_try_again));
                    ++launched;
                    return std::thread([&, work] { ++alive; work(); --alive; });
                });
            } catch (const std::system_error&) { caught = true; }
            require(caught && launched == failureIndex && alive == 0, "partial worker startup leaked a worker");
        }
        std::cout << "Prepared executor: serial/parallel partitions, zero allocation/launch dispatch, exceptions and partial startup passed.\n";
        return 0;
    } catch (const std::exception& error) {
        allocationProbe::counting = false;
        std::cerr << error.what() << '\n';
        return 1;
    }
}
