#include "WVForcingScheduleDecoder.hpp"

#include "WVNetCDF.hpp"

#include <netcdf.h>

#include <algorithm>
#include <array>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <limits>
#include <set>
#include <string>
#include <unordered_set>
#include <utility>
#include <vector>

namespace wavevortex::runtime::detail {

namespace {

WVCheckpointStatus status(WVCheckpointStatusCode code, std::string message, std::string location) {
    return {code, std::move(message), std::move(location)};
}

WVCheckpointStatus requiredTextAttribute(int groupId, const std::string& name, std::string& value, const std::string& path) {
    auto result = readTextAttribute(groupId, name, value, path);
    if (!result) return result;
    if (value.empty()) return status(WVCheckpointStatusCode::malformedForcing, "Forcing text field '" + name + "' must not be empty.", path + "/@" + name);
    return WVCheckpointStatus::ok();
}

WVCheckpointStatus optionalTextAttribute(int groupId, const std::string& name, std::string& value, const std::string& path) {
    nc_type type = NC_NAT;
    std::size_t length = 0;
    const int inquiry = nc_inq_att(groupId, NC_GLOBAL, name.c_str(), &type, &length);
    if (inquiry == NC_ENOTATT) {
        value.clear();
        return WVCheckpointStatus::ok();
    }
    if (inquiry != NC_NOERR) return netcdfFailure(inquiry, "Attribute inspection", path + "/@" + name);
    return readTextAttribute(groupId, name, value, path);
}

WVCheckpointStatus variableInfo(int groupId, const std::string& name, int& variableId, nc_type& type, std::vector<int>& dimensions, const std::string& path) {
    int result = nc_inq_varid(groupId, name.c_str(), &variableId);
    if (result == NC_ENOTVAR) return status(WVCheckpointStatusCode::missingVariable, "Missing forcing variable '" + name + "'.", path + "/" + name);
    if (result != NC_NOERR) return netcdfFailure(result, "Variable lookup", path + "/" + name);
    int dimensionCount = 0;
    result = nc_inq_vartype(groupId, variableId, &type);
    if (result == NC_NOERR) result = nc_inq_varndims(groupId, variableId, &dimensionCount);
    if (result != NC_NOERR) return netcdfFailure(result, "Variable inspection", path + "/" + name);
    dimensions.resize(static_cast<std::size_t>(dimensionCount));
    if (dimensionCount > 0) {
        result = nc_inq_vardimid(groupId, variableId, dimensions.data());
        if (result != NC_NOERR) return netcdfFailure(result, "Variable-dimension inspection", path + "/" + name);
    }
    return WVCheckpointStatus::ok();
}

WVCheckpointStatus dimensionInfo(int groupId, int dimensionId, std::string& name, std::size_t& length, const std::string& path) {
    char rawName[NC_MAX_NAME + 1] = {};
    const int result = nc_inq_dim(groupId, dimensionId, rawName, &length);
    if (result != NC_NOERR) return netcdfFailure(result, "Dimension inspection", path);
    name = rawName;
    return WVCheckpointStatus::ok();
}

WVCheckpointStatus validateVariables(int groupId, const std::set<std::string>& allowed, const std::string& path) {
    int count = 0;
    int result = nc_inq_nvars(groupId, &count);
    if (result != NC_NOERR) return netcdfFailure(result, "Variable-list inspection", path);
    std::vector<int> ids(static_cast<std::size_t>(count));
    if (count > 0) {
        result = nc_inq_varids(groupId, nullptr, ids.data());
        if (result != NC_NOERR) return netcdfFailure(result, "Variable-list inspection", path);
    }
    for (const int id : ids) {
        char rawName[NC_MAX_NAME + 1] = {};
        result = nc_inq_varname(groupId, id, rawName);
        if (result != NC_NOERR) return netcdfFailure(result, "Variable-name inspection", path);
        if (allowed.find(rawName) == allowed.end()) {
            return status(WVCheckpointStatusCode::malformedForcing, "Unsupported variable '" + std::string(rawName) + "' appears in a frozen forcing record.", path + "/" + rawName);
        }
    }
    std::vector<int> children;
    auto checkpointStatus = childGroups(groupId, children, path);
    if (!checkpointStatus) return checkpointStatus;
    if (!children.empty()) return status(WVCheckpointStatusCode::malformedForcing, "Frozen forcing records must not contain child groups.", path);
    return WVCheckpointStatus::ok();
}

WVCheckpointStatus validateComplexMarkers(int groupId, int variableId, const std::string& variableName, bool realPart, const std::string& path) {
    for (const auto& marker : std::array<std::pair<const char*, unsigned char>, 3>{{
            {"isComplex", 1}, {"isRealPart", static_cast<unsigned char>(realPart)}, {"isImaginaryPart", static_cast<unsigned char>(!realPart)}}}) {
        nc_type type = NC_NAT;
        std::size_t length = 0;
        int result = nc_inq_att(groupId, variableId, marker.first, &type, &length);
        if (result == NC_ENOTATT) return status(WVCheckpointStatusCode::missingAttribute, "Complex forcing variable is missing marker '" + std::string(marker.first) + "'.", path + "/" + variableName + "/@" + marker.first);
        if (result != NC_NOERR) return netcdfFailure(result, "Complex-marker inspection", path + "/" + variableName + "/@" + marker.first);
        if ((type != NC_UBYTE && type != NC_BYTE) || length != 1) return status(WVCheckpointStatusCode::typeMismatch, "Complex forcing marker must be a scalar byte.", path + "/" + variableName + "/@" + marker.first);
        unsigned char value = 0;
        result = nc_get_att_uchar(groupId, variableId, marker.first, &value);
        if (result != NC_NOERR) return netcdfFailure(result, "Complex-marker read", path + "/" + variableName + "/@" + marker.first);
        if (value != marker.second) return status(WVCheckpointStatusCode::malformedForcing, "Complex forcing marker has an unexpected value.", path + "/" + variableName + "/@" + marker.first);
    }
    return WVCheckpointStatus::ok();
}

WVCheckpointStatus readComplexVector(int groupId, const std::string& baseName, const std::string& dimensionName, std::size_t expectedLength, std::vector<WVComplex64>& values, const std::string& path) {
    const std::string realName = baseName + "_real";
    const std::string imagName = baseName + "_imag";
    int realId = -1;
    int imagId = -1;
    nc_type realType = NC_NAT;
    nc_type imagType = NC_NAT;
    std::vector<int> realDimensions;
    std::vector<int> imagDimensions;
    auto result = variableInfo(groupId, realName, realId, realType, realDimensions, path);
    if (!result) return result;
    result = variableInfo(groupId, imagName, imagId, imagType, imagDimensions, path);
    if (!result) return result;
    if (realType != NC_DOUBLE || imagType != NC_DOUBLE || realDimensions != imagDimensions || realDimensions.size() != 1) {
        return status(WVCheckpointStatusCode::typeMismatch, "Complex forcing values must be paired one-dimensional doubles.", path + "/" + baseName);
    }
    std::string actualDimension;
    std::size_t actualLength = 0;
    result = dimensionInfo(groupId, realDimensions.front(), actualDimension, actualLength, path + "/" + baseName);
    if (!result) return result;
    if (actualDimension != dimensionName || actualLength != expectedLength) return status(WVCheckpointStatusCode::shapeMismatch, "Complex forcing values have an incompatible dimension.", path + "/" + baseName);
    result = validateComplexMarkers(groupId, realId, realName, true, path);
    if (!result) return result;
    result = validateComplexMarkers(groupId, imagId, imagName, false, path);
    if (!result) return result;
    std::vector<double> real(expectedLength);
    std::vector<double> imag(expectedLength);
    int netcdfStatus = expectedLength == 0 ? NC_NOERR : nc_get_var_double(groupId, realId, real.data());
    if (netcdfStatus == NC_NOERR && expectedLength > 0) netcdfStatus = nc_get_var_double(groupId, imagId, imag.data());
    if (netcdfStatus != NC_NOERR) return netcdfFailure(netcdfStatus, "Complex forcing read", path + "/" + baseName);
    values.resize(expectedLength);
    for (std::size_t index = 0; index < expectedLength; ++index) {
        if (!std::isfinite(real[index]) || !std::isfinite(imag[index])) return status(WVCheckpointStatusCode::malformedForcing, "Complex forcing values must be finite.", path + "/" + baseName);
        values[index] = {real[index], imag[index]};
    }
    return WVCheckpointStatus::ok();
}

WVCheckpointStatus readSelectedCoefficients(int groupId, const std::string& prefix, std::size_t coefficientCount, std::vector<std::size_t>& indices, std::vector<WVComplex64>& values, const std::string& path) {
    const std::string indexName = prefix + "_indices";
    int indexId = -1;
    bool hasIndices = false;
    int realId = -1;
    bool hasReal = false;
    int imagId = -1;
    bool hasImag = false;
    auto result = variableIdIfPresent(groupId, indexName, indexId, hasIndices, path);
    if (!result) return result;
    result = variableIdIfPresent(groupId, prefix + "bar_real", realId, hasReal, path);
    if (!result) return result;
    result = variableIdIfPresent(groupId, prefix + "bar_imag", imagId, hasImag, path);
    if (!result) return result;
    if (!hasIndices && !hasReal && !hasImag) return WVCheckpointStatus::ok();
    if (!(hasIndices && hasReal && hasImag)) return status(WVCheckpointStatusCode::malformedForcing, "Selected coefficients require an index coordinate and paired complex values.", path + "/" + prefix);

    nc_type type = NC_NAT;
    std::vector<int> dimensions;
    result = variableInfo(groupId, indexName, indexId, type, dimensions, path);
    if (!result) return result;
    if (type != NC_UINT64 || dimensions.size() != 1) return status(WVCheckpointStatusCode::typeMismatch, "Fixed-amplitude indices must be a one-dimensional uint64 coordinate.", path + "/" + indexName);
    std::string actualDimension;
    std::size_t length = 0;
    result = dimensionInfo(groupId, dimensions.front(), actualDimension, length, path + "/" + indexName);
    if (!result) return result;
    if (actualDimension != indexName || length == 0) return status(WVCheckpointStatusCode::shapeMismatch, "Fixed-amplitude indices must use their nonempty matching dimension.", path + "/" + indexName);
    std::vector<unsigned long long> sourceIndices(length);
    const int netcdfStatus = nc_get_var_ulonglong(groupId, indexId, sourceIndices.data());
    if (netcdfStatus != NC_NOERR) return netcdfFailure(netcdfStatus, "Fixed-amplitude index read", path + "/" + indexName);
    indices.resize(length);
    std::unordered_set<std::size_t> observed;
    for (std::size_t index = 0; index < length; ++index) {
        const auto source = sourceIndices[index];
        if (source == 0 || source > coefficientCount) return status(WVCheckpointStatusCode::incompatibleForcing, "Fixed-amplitude index is outside the checkpoint coefficient array.", path + "/" + indexName);
        const std::size_t converted = static_cast<std::size_t>(source - 1);
        if (!observed.insert(converted).second) return status(WVCheckpointStatusCode::duplicateForcing, "Fixed-amplitude indices must not repeat within one coefficient family.", path + "/" + indexName);
        indices[index] = converted;
    }
    return readComplexVector(groupId, prefix + "bar", indexName, length, values, path);
}

WVCheckpointStatus readRealMatrix(int groupId, const std::string& name, const WVTransformConstantStratificationConfiguration& configuration, WVShape2D& shape, std::vector<double>& values, const std::string& path) {
    int variableId = -1;
    nc_type type = NC_NAT;
    std::vector<int> dimensions;
    auto result = variableInfo(groupId, name, variableId, type, dimensions, path);
    if (!result) return result;
    if (type != NC_DOUBLE || dimensions.size() != 2) return status(WVCheckpointStatusCode::typeMismatch, "Topographic height must be a two-dimensional double array.", path + "/" + name);
    const std::array<const char*, 2> expectedNames = {"y", "x"};
    const std::array<std::size_t, 2> expectedLengths = {configuration.Ny, configuration.Nx};
    for (std::size_t index = 0; index < dimensions.size(); ++index) {
        std::string actualName;
        std::size_t actualLength = 0;
        result = dimensionInfo(groupId, dimensions[index], actualName, actualLength, path + "/" + name);
        if (!result) return result;
        if (actualName != expectedNames[index] || actualLength != expectedLengths[index]) return status(WVCheckpointStatusCode::incompatibleForcing, "Topographic height dimensions do not match the checkpoint horizontal grid.", path + "/" + name);
    }
    if (configuration.Nx > std::numeric_limits<std::size_t>::max() / configuration.Ny) return status(WVCheckpointStatusCode::shapeMismatch, "Topographic height is too large to address.", path + "/" + name);
    values.resize(configuration.Nx * configuration.Ny);
    const int netcdfStatus = nc_get_var_double(groupId, variableId, values.data());
    if (netcdfStatus != NC_NOERR) return netcdfFailure(netcdfStatus, "Topographic height read", path + "/" + name);
    if (std::any_of(values.begin(), values.end(), [](double value) { return !std::isfinite(value); })) return status(WVCheckpointStatusCode::malformedForcing, "Topographic height must be finite.", path + "/" + name);
    shape = {configuration.Nx, configuration.Ny};
    return WVCheckpointStatus::ok();
}

WVCheckpointStatus readVelocityAmplitude(int groupId, std::array<WVComplex64, 2>& output, const std::string& path) {
    std::vector<WVComplex64> values;
    auto result = readComplexVector(groupId, "barotropicVelocityAmplitude", "barotropicVelocityComponent", 2, values, path);
    if (!result) return result;
    int coordinateId = -1;
    nc_type type = NC_NAT;
    std::vector<int> dimensions;
    result = variableInfo(groupId, "barotropicVelocityComponent", coordinateId, type, dimensions, path);
    if (!result) return result;
    if (type != NC_DOUBLE || dimensions.size() != 1) return status(WVCheckpointStatusCode::typeMismatch, "Barotropic velocity component coordinate must be a double vector.", path + "/barotropicVelocityComponent");
    std::array<double, 2> components{};
    const int netcdfStatus = nc_get_var_double(groupId, coordinateId, components.data());
    if (netcdfStatus != NC_NOERR) return netcdfFailure(netcdfStatus, "Barotropic velocity component read", path + "/barotropicVelocityComponent");
    if (components[0] != 1.0 || components[1] != 2.0) return status(WVCheckpointStatusCode::malformedForcing, "Barotropic velocity components must be [1,2].", path + "/barotropicVelocityComponent");
    output = {values[0], values[1]};
    return WVCheckpointStatus::ok();
}

WVCheckpointStatus readFiniteScalar(int groupId, const std::string& name, double& value, const std::string& path) {
    auto result = readDoubleScalar(groupId, name, value, path);
    if (!result) return result;
    if (!std::isfinite(value)) return status(WVCheckpointStatusCode::malformedForcing, "Forcing scalar '" + name + "' must be finite.", path + "/" + name);
    return WVCheckpointStatus::ok();
}

WVCheckpointStatus readBoundScalar(int groupId, const std::string& name, double& value, const std::string& path) {
    auto result = readDoubleScalar(groupId, name, value, path);
    if (!result) return result;
    if (std::isnan(value) || value < 0.0) return status(WVCheckpointStatusCode::malformedForcing, "Forcing bound '" + name + "' must be nonnegative or positive infinity.", path + "/" + name);
    return WVCheckpointStatus::ok();
}

WVCheckpointStatus commonRecord(WVForcingKind kind, const WVForcingGroupSource& source, std::string name, WVForcingStage stage, std::uint8_t priority, WVForcingPayload payload, WVFrozenForcingEntry& entry) {
    if (name.empty()) return status(WVCheckpointStatusCode::malformedForcing, "Forcing name must not be empty.", source.groupPath + "/@name");
    entry.kind = kind;
    entry.typeIdentifier = source.annotatedClass;
    entry.name = std::move(name);
    entry.stage = stage;
    entry.priority = priority;
    entry.ordinal = source.ordinal;
    entry.sourceGroupPath = source.groupPath;
    entry.payload = std::move(payload);
    return WVCheckpointStatus::ok();
}

WVCheckpointStatus decodeSupported(const WVForcingGroupSource& source, const WVTransformConstantStratificationConfiguration& configuration, std::size_t coefficientCount, WVFrozenForcingEntry& entry) {
    const auto* capability = forcingCapability(source.annotatedClass);
    if (capability == nullptr) return status(WVCheckpointStatusCode::unsupportedForcing, "Unknown forcing class '" + source.annotatedClass + "'.", source.groupPath + "/@AnnotatedClass");
    if (!capability->isSupported) return status(WVCheckpointStatusCode::unsupportedForcing, capability->unavailabilityReason, source.groupPath + "/@AnnotatedClass");

    switch (capability->kind) {
        case WVForcingKind::nonlinearAdvection: {
            auto result = validateVariables(source.groupId, {}, source.groupPath);
            if (!result) return result;
            return commonRecord(capability->kind, source, "nonlinear advection", WVForcingStage::spatial, 127, WVNonlinearAdvectionRecord{}, entry);
        }
        case WVForcingKind::adaptiveDamping: {
            auto result = validateVariables(source.groupId, {}, source.groupPath);
            if (!result) return result;
            return commonRecord(capability->kind, source, "adaptive damping", WVForcingStage::spectral, 255, WVAdaptiveDampingRecord{}, entry);
        }
        case WVForcingKind::betaPlanePVAdvection: {
            auto result = validateVariables(source.groupId, {}, source.groupPath);
            if (!result) return result;
            return commonRecord(capability->kind, source, "beta-plane advection of qgpv", WVForcingStage::spectral, 255, WVBetaPlanePVAdvectionRecord{}, entry);
        }
        case WVForcingKind::bottomFrictionQuadratic: {
            auto result = validateVariables(source.groupId, {"Cd"}, source.groupPath);
            if (!result) return result;
            WVBottomFrictionQuadraticRecord record;
            result = readFiniteScalar(source.groupId, "Cd", record.Cd, source.groupPath);
            if (!result) return result;
            if (record.Cd < 0.0) return status(WVCheckpointStatusCode::malformedForcing, "Quadratic drag coefficient Cd must be nonnegative.", source.groupPath + "/Cd");
            return commonRecord(capability->kind, source, "quadratic bottom friction", WVForcingStage::spatial, 255, std::move(record), entry);
        }
        case WVForcingKind::fixedAmplitude: {
            const std::set<std::string> variables = {"Ap_indices", "Apbar_real", "Apbar_imag", "Am_indices", "Ambar_real", "Ambar_imag", "A0_indices", "A0bar_real", "A0bar_imag"};
            auto result = validateVariables(source.groupId, variables, source.groupPath);
            if (!result) return result;
            std::string name;
            result = requiredTextAttribute(source.groupId, "name", name, source.groupPath);
            if (!result) return result;
            WVFixedAmplitudeForcingRecord record;
            result = readSelectedCoefficients(source.groupId, "Ap", coefficientCount, record.ApIndices, record.ApValues, source.groupPath);
            if (!result) return result;
            result = readSelectedCoefficients(source.groupId, "Am", coefficientCount, record.AmIndices, record.AmValues, source.groupPath);
            if (!result) return result;
            result = readSelectedCoefficients(source.groupId, "A0", coefficientCount, record.A0Indices, record.A0Values, source.groupPath);
            if (!result) return result;
            return commonRecord(capability->kind, source, std::move(name), WVForcingStage::spectralAmplitude, 255, std::move(record), entry);
        }
        case WVForcingKind::pseudoTopographicWaveGeneration: {
            const std::set<std::string> variables = {"topographicHeight", "barotropicVelocityComponent", "barotropicVelocityAmplitude_real", "barotropicVelocityAmplitude_imag", "frequency", "rampDuration", "startTime", "shouldAvoidAdaptiveDamping", "maximumForcedHorizontalWavenumber", "maximumForcedVerticalMode"};
            auto result = validateVariables(source.groupId, variables, source.groupPath);
            if (!result) return result;
            std::string name;
            result = requiredTextAttribute(source.groupId, "name", name, source.groupPath);
            if (!result) return result;
            WVPseudoTopographicWaveGenerationRecord record;
            result = readRealMatrix(source.groupId, "topographicHeight", configuration, record.topographicShape, record.topographicHeight, source.groupPath);
            if (!result) return result;
            result = readVelocityAmplitude(source.groupId, record.barotropicVelocityAmplitude, source.groupPath);
            if (!result) return result;
            result = readFiniteScalar(source.groupId, "frequency", record.frequency, source.groupPath);
            if (!result) return result;
            if (record.frequency <= 0.0) return status(WVCheckpointStatusCode::malformedForcing, "Pseudo-topographic frequency must be positive.", source.groupPath + "/frequency");
            result = optionalTextAttribute(source.groupId, "darwinSymbol", record.darwinSymbol, source.groupPath);
            if (!result) return result;
            static const std::set<std::string> darwinSymbols = {"", "M2", "S2", "N2", "K1", "O1"};
            if (darwinSymbols.find(record.darwinSymbol) == darwinSymbols.end()) return status(WVCheckpointStatusCode::malformedForcing, "Pseudo-topographic Darwin symbol is not recognized.", source.groupPath + "/@darwinSymbol");
            result = readFiniteScalar(source.groupId, "rampDuration", record.rampDuration, source.groupPath);
            if (!result) return result;
            if (record.rampDuration < 0.0) return status(WVCheckpointStatusCode::malformedForcing, "Pseudo-topographic rampDuration must be nonnegative.", source.groupPath + "/rampDuration");
            result = readFiniteScalar(source.groupId, "startTime", record.startTime, source.groupPath);
            if (!result) return result;
            result = readLogicalScalar(source.groupId, "shouldAvoidAdaptiveDamping", record.shouldAvoidAdaptiveDamping, source.groupPath);
            if (!result) return result;
            result = readBoundScalar(source.groupId, "maximumForcedHorizontalWavenumber", record.maximumForcedHorizontalWavenumber, source.groupPath);
            if (!result) return result;
            result = readBoundScalar(source.groupId, "maximumForcedVerticalMode", record.maximumForcedVerticalMode, source.groupPath);
            if (!result) return result;
            return commonRecord(capability->kind, source, std::move(name), WVForcingStage::spectral, 255, std::move(record), entry);
        }
        default:
            return status(WVCheckpointStatusCode::unsupportedForcing, "Forcing class is not supported by portable runtime v1.", source.groupPath + "/@AnnotatedClass");
    }
}

std::uint8_t stageRank(WVForcingStage stage) noexcept {
    return static_cast<std::uint8_t>(stage);
}

} // namespace

WVCheckpointStatus decodeForcingSchedule(
    const std::vector<WVForcingGroupSource>& sources,
    const WVTransformConstantStratificationConfiguration& configuration,
    std::size_t coefficientCount,
    WVFrozenForcingSchedule& schedule) {
    WVFrozenForcingSchedule candidate;
    candidate.entries.reserve(sources.size());
    std::unordered_set<std::string> names;
    for (const auto& source : sources) {
        WVFrozenForcingEntry entry;
        auto result = decodeSupported(source, configuration, coefficientCount, entry);
        if (!result) return result;
        if (!names.insert(entry.name).second) return status(WVCheckpointStatusCode::duplicateForcing, "Forcing names must be unique; duplicate name '" + entry.name + "'.", source.groupPath + "/@name");
        candidate.entries.push_back(std::move(entry));
    }
    std::stable_sort(candidate.entries.begin(), candidate.entries.end(), [](const auto& left, const auto& right) {
        if (stageRank(left.stage) != stageRank(right.stage)) return stageRank(left.stage) < stageRank(right.stage);
        if (left.priority != right.priority) return left.priority < right.priority;
        return left.ordinal < right.ordinal;
    });
    schedule = std::move(candidate);
    return WVCheckpointStatus::ok();
}

} // namespace wavevortex::runtime::detail
