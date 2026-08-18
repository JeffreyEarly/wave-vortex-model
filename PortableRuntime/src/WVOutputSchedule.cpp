#include "WaveVortexRuntime/WVOutputSchedule.hpp"

#include <algorithm>
#include <cmath>
#include <limits>
#include <map>
#include <mutex>
#include <tuple>
#include <utility>

namespace wavevortex::runtime {
namespace {

using Key = std::pair<std::string, std::uint32_t>;

double tolerance(double first, double second) noexcept {
  return 8.0 * std::numeric_limits<double>::epsilon() *
         std::max({1.0, std::abs(first), std::abs(second)});
}

WVKernelStatus invalid(std::string message) {
  return {WVKernelStatusCode::invalidConfiguration, std::move(message)};
}

class WVEvenlySpacedSchedule final : public WVOutputSchedule {
public:
  explicit WVEvenlySpacedSchedule(const WVOutputScheduleRecord &record)
      : anchor_(record.initialTime), interval_(record.outputInterval),
        final_(record.finalTime) {}

  const char *typeIdentifier() const noexcept override {
    return WVEvenlySpacedOutputScheduleType;
  }
  std::uint32_t contractVersion() const noexcept override { return 1; }

  WVKernelStatus
  validateCursor(const WVOutputScheduleCursor &cursor) const override {
    if (cursor.committedOrdinal < WVNoCommittedOutputOrdinal)
      return invalid("An output-schedule ordinal cannot be less than -1.");
    if (!cursor.values.schemaIdentifier.empty() ||
        cursor.values.schemaVersion != 0 || !cursor.values.values.empty())
      return invalid("The evenly-spaced schedule cursor contains unexpected "
                     "provider state.");
    if (cursor.committedOrdinal >= 0) {
      const auto time = std::fma(static_cast<double>(cursor.committedOrdinal),
                                 interval_, anchor_);
      if (!std::isfinite(time) || time > final_ + tolerance(time, final_))
        return invalid("Committed output progress lies beyond its schedule.");
    }
    return WVKernelStatus::ok();
  }

  WVKernelStatus committedTime(const WVOutputScheduleCursor &cursor,
                               double &time, bool &available) const override {
    auto status = validateCursor(cursor);
    if (!status)
      return status;
    available = cursor.committedOrdinal >= 0;
    if (available)
      time = std::fma(static_cast<double>(cursor.committedOrdinal), interval_,
                      anchor_);
    return WVKernelStatus::ok();
  }

  WVKernelStatus peek(const WVOutputScheduleCursor &cursor, double lowerBound,
                      double upperBound, WVOutputScheduleOccurrence &occurrence,
                      bool &available) const override {
    available = false;
    auto status = validateCursor(cursor);
    if (!status)
      return status;
    if (!std::isfinite(lowerBound) || !std::isfinite(upperBound) ||
        upperBound < lowerBound)
      return invalid(
          "Output-schedule bounds must be finite and nondecreasing.");
    const auto lower = std::max(lowerBound, anchor_);
    const auto upper = std::min(upperBound, final_);
    if (upper + tolerance(lower, upper) < lower)
      return WVKernelStatus::ok();
    const long double ratio =
        (static_cast<long double>(lower) - static_cast<long double>(anchor_)) /
        static_cast<long double>(interval_);
    const long double allowance =
        static_cast<long double>(tolerance(anchor_, lower) / interval_);
    const auto candidate = std::ceil(ratio - allowance);
    if (candidate > static_cast<long double>(
                        std::numeric_limits<WVOutputScheduleOrdinal>::max()))
      return {WVKernelStatusCode::sizeOverflow,
              "Output schedule ordinal exceeds int64 capacity."};
    auto ordinal = candidate <= 0.0L
                       ? WVOutputScheduleOrdinal{0}
                       : static_cast<WVOutputScheduleOrdinal>(candidate);
    if (cursor.committedOrdinal >= ordinal) {
      if (cursor.committedOrdinal ==
          std::numeric_limits<WVOutputScheduleOrdinal>::max())
        return {WVKernelStatusCode::sizeOverflow,
                "Output schedule ordinal overflowed int64 capacity."};
      ordinal = cursor.committedOrdinal + 1;
    }
    const auto time =
        std::fma(static_cast<double>(ordinal), interval_, anchor_);
    if (!std::isfinite(time))
      return {WVKernelStatusCode::sizeOverflow,
              "Output schedule time overflowed finite precision."};
    if (time > upper + tolerance(time, upper))
      return WVKernelStatus::ok();
    occurrence = {time, ordinal, {ordinal, {}}};
    available = true;
    return WVKernelStatus::ok();
  }

  std::size_t persistentBytes() const noexcept override {
    return sizeof(*this);
  }

private:
  double anchor_ = 0.0;
  double interval_ = 0.0;
  double final_ = 0.0;
};

std::map<Key, WVOutputScheduleFactoryRegistry::Factory> &factories() {
  static std::map<Key, WVOutputScheduleFactoryRegistry::Factory> value;
  return value;
}

std::mutex &factoryMutex() {
  static std::mutex value;
  return value;
}

bool &sealed() {
  static bool value = false;
  return value;
}

std::shared_ptr<const WVOutputSchedule>
makeEvenlySpaced(const WVOutputScheduleRecord &record, WVKernelStatus &status) {
  if (!std::isfinite(record.initialTime) ||
      !std::isfinite(record.outputInterval) || record.outputInterval <= 0.0 ||
      std::isnan(record.finalTime) || record.finalTime < record.initialTime) {
    status = invalid("The evenly-spaced output schedule is invalid.");
    return {};
  }
  if (!record.configuration.schemaIdentifier.empty() ||
      record.configuration.schemaVersion != 0 ||
      !record.configuration.values.empty()) {
    status = invalid("A legacy evenly-spaced schedule cannot carry a typed "
                     "configuration record.");
    return {};
  }
  if (record.finalTime > record.initialTime) {
    const long double ratio = (static_cast<long double>(record.finalTime) -
                               static_cast<long double>(record.initialTime)) /
                              static_cast<long double>(record.outputInterval);
    const auto lastCandidate = std::floor(ratio);
    if (lastCandidate >= 1.0L &&
        lastCandidate <=
            static_cast<long double>(
                std::numeric_limits<WVOutputScheduleOrdinal>::max())) {
      const auto last = static_cast<WVOutputScheduleOrdinal>(lastCandidate);
      const auto current = std::fma(static_cast<double>(last),
                                    record.outputInterval, record.initialTime);
      const auto previous = std::fma(static_cast<double>(last - 1),
                                     record.outputInterval, record.initialTime);
      if (!std::isfinite(current) || !(current > previous)) {
        status = invalid("Output schedule ordinals are not distinguishable in "
                         "finite precision.");
        return {};
      }
    }
  }
  try {
    status = WVKernelStatus::ok();
    return std::make_shared<WVEvenlySpacedSchedule>(record);
  } catch (const std::bad_alloc &) {
    status = {WVKernelStatusCode::allocationFailure,
              "Unable to allocate an output schedule."};
    return {};
  }
}

void ensureBuiltins() {
  auto &items = factories();
  const Key key{WVEvenlySpacedOutputScheduleType, 1};
  if (items.find(key) == items.end())
    items.emplace(key, &makeEvenlySpaced);
}

} // namespace

WVKernelStatus
WVOutputScheduleFactoryRegistry::registerFactory(std::string typeIdentifier,
                                                 std::uint32_t contractVersion,
                                                 Factory factory) {
  if (typeIdentifier.empty() || contractVersion == 0 || factory == nullptr)
    return invalid("An output-schedule factory requires an identity, positive "
                   "version, and function.");
  std::lock_guard<std::mutex> lock(factoryMutex());
  ensureBuiltins();
  if (sealed())
    return invalid("Output-schedule registration is sealed.");
  if (!factories()
           .emplace(Key{std::move(typeIdentifier), contractVersion}, factory)
           .second)
    return invalid("An output-schedule factory is already registered for this "
                   "identity and version.");
  return WVKernelStatus::ok();
}

WVKernelStatus WVOutputScheduleFactoryRegistry::resolve(
    const WVOutputScheduleRecord &record,
    std::shared_ptr<const WVOutputSchedule> &result) {
  Factory factory = nullptr;
  WVOutputScheduleRecord normalized = record;
  if (normalized.typeIdentifier.empty()) {
    normalized.typeIdentifier = WVEvenlySpacedOutputScheduleType;
    normalized.contractVersion = 1;
  }
  {
    std::lock_guard<std::mutex> lock(factoryMutex());
    ensureBuiltins();
    sealed() = true;
    const auto found = factories().find(
        Key{normalized.typeIdentifier, normalized.contractVersion});
    if (found == factories().end() &&
        normalized.typeIdentifier == WVStateTriggeredOutputScheduleType)
      return {WVKernelStatusCode::unsupportedOperation,
              "State-triggered output schedules are reserved but unsupported."};
    if (found == factories().end())
      return {WVKernelStatusCode::unsupportedOperation,
              "No output-schedule implementation is registered for " +
                  normalized.typeIdentifier + " version " +
                  std::to_string(normalized.contractVersion) + "."};
    factory = found->second;
  }
  WVKernelStatus status;
  auto candidate = factory(normalized, status);
  if (!status)
    return status;
  if (!candidate || candidate->typeIdentifier() != normalized.typeIdentifier ||
      candidate->contractVersion() != normalized.contractVersion)
    return invalid("An output-schedule factory returned an incompatible "
                   "implementation.");
  result = std::move(candidate);
  return WVKernelStatus::ok();
}

bool WVOutputScheduleFactoryRegistry::isSealed() noexcept {
  std::lock_guard<std::mutex> lock(factoryMutex());
  return sealed();
}

} // namespace wavevortex::runtime
