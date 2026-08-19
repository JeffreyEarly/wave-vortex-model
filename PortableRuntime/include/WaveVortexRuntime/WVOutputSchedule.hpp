#pragma once

#include "WaveVortexRuntime/WVObserverContracts.hpp"

#include <cstddef>
#include <cstdint>
#include <memory>
#include <string>

namespace wavevortex::runtime {

using WVOutputScheduleOrdinal = std::int64_t;
inline constexpr WVOutputScheduleOrdinal WVNoCommittedOutputOrdinal = -1;
inline constexpr std::size_t WVMaximumOutputScheduleCursorBytes = 4096;
inline constexpr const char *WVEvenlySpacedOutputScheduleType =
    "WVEvenlySpacedOutputSchedule";
inline constexpr const char *WVStateTriggeredOutputScheduleType =
    "WVStateTriggeredOutputSchedule";

struct WVOutputScheduleCursor {
  WVOutputScheduleOrdinal committedOrdinal = WVNoCommittedOutputOrdinal;
  WVPortableTypedRecord values;
};

struct WVOutputScheduleOccurrence {
  double scheduledTime = 0.0;
  WVOutputScheduleOrdinal ordinal = WVNoCommittedOutputOrdinal;
  WVOutputScheduleCursor proposedCursor;
};

// Provisional source-linked schedule boundary. Implementations are immutable
// after construction. peek() is transactional: the caller owns and commits the
// proposed cursor only after the corresponding output route is delivered.
class WVOutputSchedule {
public:
  virtual ~WVOutputSchedule() = default;
  virtual const char *typeIdentifier() const noexcept = 0;
  virtual std::uint32_t contractVersion() const noexcept = 0;
  virtual WVKernelStatus
  validateCursor(const WVOutputScheduleCursor &cursor) const = 0;
  virtual WVKernelStatus committedTime(const WVOutputScheduleCursor &cursor,
                                       double &time, bool &available) const = 0;
  virtual WVKernelStatus peek(const WVOutputScheduleCursor &cursor,
                              double lowerBound, double upperBound,
                              WVOutputScheduleOccurrence &occurrence,
                              bool &available) const = 0;
  virtual std::size_t persistentBytes() const noexcept = 0;
};

using WVOutputScheduleFactory = std::shared_ptr<const WVOutputSchedule> (*)(
    const WVOutputScheduleRecord &, WVKernelStatus &);

std::shared_ptr<const WVOutputSchedule>
makeEvenlySpacedOutputSchedule(const WVOutputScheduleRecord &record,
                              WVKernelStatus &status);

} // namespace wavevortex::runtime
