#include "WVModelOutputNetCDFSchema.hpp"

#include "WVNetCDF.hpp"

#include <netcdf.h>

#include <algorithm>
#include <array>
#include <chrono>
#include <ctime>
#include <iomanip>
#include <sstream>
#include <utility>
#include <variant>

namespace wavevortex::runtime::detail {
namespace {

WVCheckpointStatus failed(WVCheckpointStatusCode code, std::string message,
                          std::string location) {
  return {code, std::move(message), std::move(location)};
}

WVCheckpointStatus defineLogical(int group, const std::string &name,
                                 int &variable, const std::string &path) {
  auto result = checkedNetCDF(
      nc_def_var(group, name.c_str(), NC_UBYTE, 0, nullptr, &variable),
      "Variable definition", path + "/" + name);
  if (!result)
    return result;
  return putByteAttribute(group, variable, "isLogicalType", 1,
                          path + "/" + name);
}

WVCheckpointStatus defineFixedFamily(int group, const char *prefix,
                                     std::size_t length,
                                     const std::string &path) {
  if (length == 0)
    return WVCheckpointStatus::ok();
  const std::string indexName = std::string(prefix) + "_indices";
  int dimension = -1;
  auto result =
      checkedNetCDF(nc_def_dim(group, indexName.c_str(), length, &dimension),
                    "Forcing dimension definition", path + "/" + indexName);
  if (!result)
    return result;
  int variable = -1;
  result = checkedNetCDF(
      nc_def_var(group, indexName.c_str(), NC_UINT64, 1, &dimension, &variable),
      "Forcing variable definition", path + "/" + indexName);
  if (!result)
    return result;
  return defineComplexVariable(group, std::string(prefix) + "bar", {dimension},
                               path);
}

WVCheckpointStatus defineForcingEntry(int group,
                                      const WVFrozenForcingEntry &entry,
                                      const std::array<int, 5> &rootDimensions,
                                      const std::string &path) {
  auto result = putTextAttribute(group, NC_GLOBAL, "AnnotatedClass",
                                 entry.typeIdentifier, path);
  if (!result)
    return result;
  switch (entry.kind) {
  case WVForcingKind::nonlinearAdvection:
  case WVForcingKind::adaptiveDamping:
  case WVForcingKind::betaPlanePVAdvection:
    return WVCheckpointStatus::ok();
  case WVForcingKind::bottomFrictionQuadratic: {
    int variable = -1;
    return defineDoubleVariable(group, "Cd", {}, variable, path);
  }
  case WVForcingKind::fixedAmplitude: {
    result = putTextAttribute(group, NC_GLOBAL, "name", entry.name, path);
    if (!result)
      return result;
    const auto &record = std::get<WVFixedAmplitudeForcingRecord>(entry.payload);
    result = defineFixedFamily(group, "Ap", record.ApIndices.size(), path);
    if (!result)
      return result;
    result = defineFixedFamily(group, "Am", record.AmIndices.size(), path);
    if (!result)
      return result;
    return defineFixedFamily(group, "A0", record.A0Indices.size(), path);
  }
  case WVForcingKind::pseudoTopographicWaveGeneration: {
    const auto &record =
        std::get<WVPseudoTopographicWaveGenerationRecord>(entry.payload);
    result = putTextAttribute(group, NC_GLOBAL, "name", entry.name, path);
    if (!result)
      return result;
    if (!record.darwinSymbol.empty()) {
      result = putTextAttribute(group, NC_GLOBAL, "darwinSymbol",
                                record.darwinSymbol, path);
      if (!result)
        return result;
    }
    int componentDimension = -1;
    result = checkedNetCDF(nc_def_dim(group, "barotropicVelocityComponent", 2,
                                      &componentDimension),
                           "Forcing dimension definition",
                           path + "/barotropicVelocityComponent");
    if (!result)
      return result;
    int variable = -1;
    result = defineDoubleVariable(group, "barotropicVelocityComponent",
                                  {componentDimension}, variable, path);
    if (!result)
      return result;
    result = defineComplexVariable(group, "barotropicVelocityAmplitude",
                                   {componentDimension}, path);
    if (!result)
      return result;
    for (const char *name :
         {"frequency", "rampDuration", "startTime",
          "maximumForcedHorizontalWavenumber", "maximumForcedVerticalMode"}) {
      result = defineDoubleVariable(group, name, {}, variable, path);
      if (!result)
        return result;
    }
    result = defineLogical(group, "shouldAvoidAdaptiveDamping", variable, path);
    if (!result)
      return result;
    return defineDoubleVariable(group, "topographicHeight",
                                {rootDimensions[3], rootDimensions[2]},
                                variable, path);
  }
  default:
    break;
  }
  return failed(WVCheckpointStatusCode::unsupportedForcing,
                "Unsupported forcing reached output definition.", path);
}

WVCheckpointStatus variableId(int group, const std::string &name, int &variable,
                              const std::string &path) {
  return checkedNetCDF(nc_inq_varid(group, name.c_str(), &variable),
                       "Variable lookup", path + "/" + name);
}

WVCheckpointStatus writeDouble(int group, const std::string &name, double value,
                               const std::string &path) {
  int variable = -1;
  auto result = variableId(group, name, variable, path);
  if (!result)
    return result;
  return checkedNetCDF(nc_put_var_double(group, variable, &value),
                       "Variable write", path + "/" + name);
}

WVCheckpointStatus writeLogical(int group, const std::string &name, bool value,
                                const std::string &path) {
  int variable = -1;
  auto result = variableId(group, name, variable, path);
  if (!result)
    return result;
  const unsigned char raw = value ? 1 : 0;
  return checkedNetCDF(nc_put_var_uchar(group, variable, &raw),
                       "Variable write", path + "/" + name);
}

WVCheckpointStatus writeDoubles(int group, const std::string &name,
                                const std::vector<double> &values,
                                const std::string &path) {
  int variable = -1;
  auto result = variableId(group, name, variable, path);
  if (!result)
    return result;
  return checkedNetCDF(nc_put_var_double(group, variable, values.data()),
                       "Variable write", path + "/" + name);
}

WVCheckpointStatus writeComplex(int group, const std::string &name,
                                const std::vector<WVComplex64> &values,
                                const std::string &path) {
  std::vector<double> real(values.size());
  std::vector<double> imag(values.size());
  for (std::size_t index = 0; index < values.size(); ++index) {
    real[index] = values[index].real;
    imag[index] = values[index].imag;
  }
  auto result = writeDoubles(group, name + "_real", real, path);
  if (!result)
    return result;
  return writeDoubles(group, name + "_imag", imag, path);
}

WVCheckpointStatus writeFixedFamily(int group, const char *prefix,
                                    const std::vector<std::size_t> &indices,
                                    const std::vector<WVComplex64> &values,
                                    const std::string &path) {
  if (indices.empty())
    return WVCheckpointStatus::ok();
  std::vector<unsigned long long> oneBased(indices.size());
  for (std::size_t index = 0; index < indices.size(); ++index)
    oneBased[index] = static_cast<unsigned long long>(indices[index] + 1);
  int variable = -1;
  const std::string name = std::string(prefix) + "_indices";
  auto result = variableId(group, name, variable, path);
  if (!result)
    return result;
  result = checkedNetCDF(nc_put_var_ulonglong(group, variable, oneBased.data()),
                         "Forcing index write", path + "/" + name);
  if (!result)
    return result;
  return writeComplex(group, std::string(prefix) + "bar", values, path);
}

WVCheckpointStatus writeForcingEntry(int group,
                                     const WVFrozenForcingEntry &entry,
                                     const std::string &path) {
  switch (entry.kind) {
  case WVForcingKind::nonlinearAdvection:
  case WVForcingKind::adaptiveDamping:
  case WVForcingKind::betaPlanePVAdvection:
    return WVCheckpointStatus::ok();
  case WVForcingKind::bottomFrictionQuadratic:
    return writeDouble(
        group, "Cd",
        std::get<WVBottomFrictionQuadraticRecord>(entry.payload).Cd, path);
  case WVForcingKind::fixedAmplitude: {
    const auto &record = std::get<WVFixedAmplitudeForcingRecord>(entry.payload);
    auto result =
        writeFixedFamily(group, "Ap", record.ApIndices, record.ApValues, path);
    if (!result)
      return result;
    result =
        writeFixedFamily(group, "Am", record.AmIndices, record.AmValues, path);
    if (!result)
      return result;
    return writeFixedFamily(group, "A0", record.A0Indices, record.A0Values,
                            path);
  }
  case WVForcingKind::pseudoTopographicWaveGeneration: {
    const auto &record =
        std::get<WVPseudoTopographicWaveGenerationRecord>(entry.payload);
    auto result = writeDoubles(group, "topographicHeight",
                               record.topographicHeight, path);
    if (!result)
      return result;
    result =
        writeDoubles(group, "barotropicVelocityComponent", {1.0, 2.0}, path);
    if (!result)
      return result;
    const std::vector<WVComplex64> amplitudes(
        record.barotropicVelocityAmplitude.begin(),
        record.barotropicVelocityAmplitude.end());
    result =
        writeComplex(group, "barotropicVelocityAmplitude", amplitudes, path);
    if (!result)
      return result;
    for (const auto &scalar : std::array<std::pair<const char *, double>, 5>{
             {{"frequency", record.frequency},
              {"rampDuration", record.rampDuration},
              {"startTime", record.startTime},
              {"maximumForcedHorizontalWavenumber",
               record.maximumForcedHorizontalWavenumber},
              {"maximumForcedVerticalMode",
               record.maximumForcedVerticalMode}}}) {
      result = writeDouble(group, scalar.first, scalar.second, path);
      if (!result)
        return result;
    }
    return writeLogical(group, "shouldAvoidAdaptiveDamping",
                        record.shouldAvoidAdaptiveDamping, path);
  }
  default:
    break;
  }
  return failed(WVCheckpointStatusCode::unsupportedForcing,
                "Unsupported forcing reached output writing.", path);
}

} // namespace

WVCheckpointStatus checkedNetCDF(int code, const std::string &operation,
                                 const std::string &location) {
  return code == NC_NOERR ? WVCheckpointStatus::ok()
                          : netcdfFailure(code, operation, location);
}

WVCheckpointStatus putTextAttribute(int group, int variable, const char *name,
                                    const std::string &value,
                                    const std::string &location) {
  return checkedNetCDF(
      nc_put_att_text(group, variable, name, value.size(), value.data()),
      "Text-attribute definition", location + "/@" + name);
}

WVCheckpointStatus putByteAttribute(int group, int variable, const char *name,
                                    unsigned char value,
                                    const std::string &location) {
  return checkedNetCDF(
      nc_put_att_uchar(group, variable, name, NC_UBYTE, 1, &value),
      "Byte-attribute definition", location + "/@" + name);
}

WVCheckpointStatus defineDoubleVariable(int group, const std::string &name,
                                        const std::vector<int> &dimensions,
                                        int &variable,
                                        const std::string &path) {
  return checkedNetCDF(
      nc_def_var(group, name.c_str(), NC_DOUBLE,
                 static_cast<int>(dimensions.size()),
                 dimensions.empty() ? nullptr : dimensions.data(), &variable),
      "Variable definition", path + "/" + name);
}

WVCheckpointStatus defineComplexVariable(int group, const std::string &name,
                                         const std::vector<int> &dimensions,
                                         const std::string &path) {
  int real = -1;
  int imag = -1;
  auto result =
      defineDoubleVariable(group, name + "_real", dimensions, real, path);
  if (!result)
    return result;
  result = defineDoubleVariable(group, name + "_imag", dimensions, imag, path);
  if (!result)
    return result;
  for (const auto &marker :
       std::array<std::pair<const char *, unsigned char>, 3>{
           {{"isComplex", 1}, {"isRealPart", 1}, {"isImaginaryPart", 0}}}) {
    result = putByteAttribute(group, real, marker.first, marker.second,
                              path + "/" + name + "_real");
    if (!result)
      return result;
  }
  for (const auto &marker :
       std::array<std::pair<const char *, unsigned char>, 3>{
           {{"isComplex", 1}, {"isRealPart", 0}, {"isImaginaryPart", 1}}}) {
    result = putByteAttribute(group, imag, marker.first, marker.second,
                              path + "/" + name + "_imag");
    if (!result)
      return result;
  }
  return WVCheckpointStatus::ok();
}

WVCheckpointStatus defineModelOutputRoot(
    int root, const WVCheckpoint &checkpoint, bool isDynamicsLinear,
    std::array<int, 5> &dimensions, std::vector<int> &forcingGroups,
    std::vector<const WVFrozenForcingEntry *> &forcingEntries) {
  const auto &configuration = checkpoint.configuration;
  const std::array<std::pair<const char *, std::size_t>, 5> definitions = {
      {{"j", configuration.Nj},
       {"kl", checkpoint.state.coefficients.shape.columns},
       {"x", configuration.Nx},
       {"y", configuration.Ny},
       {"z", configuration.Nz}}};
  for (std::size_t index = 0; index < definitions.size(); ++index) {
    auto result = checkedNetCDF(
        nc_def_dim(root, definitions[index].first, definitions[index].second,
                   &dimensions[index]),
        "Dimension definition", "/" + std::string(definitions[index].first));
    if (!result)
      return result;
    int variable = -1;
    result = defineDoubleVariable(root, definitions[index].first,
                                  {dimensions[index]}, variable, "/");
    if (!result)
      return result;
  }
  for (const char *name : {"Lx", "Ly", "Lz", "N0", "g", "latitude",
                           "planetaryRadius", "rho0", "rotationRate", "t0"}) {
    int variable = -1;
    const auto result = defineDoubleVariable(root, name, {}, variable, "/");
    if (!result)
      return result;
  }
  for (const char *name : {"isHydrostatic", "shouldAntialias"}) {
    int variable = -1;
    const auto result = defineLogical(root, name, variable, "/");
    if (!result)
      return result;
  }
  auto result = putTextAttribute(root, NC_GLOBAL, "AnnotatedClass",
                                 "WVTransformConstantStratification", "/");
  if (!result)
    return result;
  result = putTextAttribute(root, NC_GLOBAL, "WVTransform",
                            "WVTransformConstantStratification", "/");
  if (!result)
    return result;
  result = putTextAttribute(root, NC_GLOBAL, "model_version",
                            checkpoint.metadata.modelVersion, "/");
  if (!result)
    return result;
  result = putByteAttribute(root, NC_GLOBAL, "WVModelIsDynamicsLinear",
                            isDynamicsLinear ? 1 : 0, "/");
  if (!result)
    return result;
  result =
      putTextAttribute(root, NC_GLOBAL, "source",
                       "Created with the WaveVortex portable runtime", "/");
  if (!result)
    return result;
  result = putTextAttribute(root, NC_GLOBAL, "history",
                            "MATLAB-compatible multi-group output initialized "
                            "by the WaveVortex portable runtime.",
                            "/");
  if (!result)
    return result;
  const auto now =
      std::chrono::system_clock::to_time_t(std::chrono::system_clock::now());
  std::tm utc{};
#if defined(_WIN32)
  gmtime_s(&utc, &now);
#else
  gmtime_r(&now, &utc);
#endif
  std::ostringstream date;
  date << std::put_time(&utc, "%Y-%m-%d %H:%M:%S UTC");
  result = putTextAttribute(root, NC_GLOBAL, "date_created", date.str(), "/");
  if (!result)
    return result;

  forcingEntries.clear();
  for (const auto &entry : checkpoint.forcingSchedule.entries)
    forcingEntries.push_back(&entry);
  std::sort(forcingEntries.begin(), forcingEntries.end(),
            [](const auto *left, const auto *right) {
              return left->ordinal < right->ordinal;
            });
  if (forcingEntries.empty())
    return WVCheckpointStatus::ok();
  int forcingRoot = -1;
  result = checkedNetCDF(nc_def_grp(root, "forcing", &forcingRoot),
                         "Forcing-group definition", "/forcing");
  if (!result)
    return result;
  forcingGroups.reserve(forcingEntries.size());
  if (forcingEntries.size() == 1) {
    forcingGroups.push_back(forcingRoot);
    return defineForcingEntry(forcingRoot, *forcingEntries.front(), dimensions,
                              "/forcing");
  }
  for (std::size_t index = 0; index < forcingEntries.size(); ++index) {
    int group = -1;
    const std::string name = "forcing-" + std::to_string(index + 1);
    result = checkedNetCDF(nc_def_grp(forcingRoot, name.c_str(), &group),
                           "Forcing-group definition", "/forcing/" + name);
    if (!result)
      return result;
    forcingGroups.push_back(group);
    result = defineForcingEntry(group, *forcingEntries[index], dimensions,
                                "/forcing/" + name);
    if (!result)
      return result;
  }
  return WVCheckpointStatus::ok();
}

WVCheckpointStatus writeModelOutputRoot(
    int root, const WVCheckpoint &checkpoint,
    const std::vector<int> &forcingGroups,
    const std::vector<const WVFrozenForcingEntry *> &forcingEntries) {
  const auto &configuration = checkpoint.configuration;
  std::vector<double> j(configuration.Nj),
      kl(checkpoint.state.coefficients.shape.columns), x(configuration.Nx),
      y(configuration.Ny), z(configuration.Nz);
  for (std::size_t index = 0; index < j.size(); ++index)
    j[index] = static_cast<double>(index);
  for (std::size_t index = 0; index < kl.size(); ++index)
    kl[index] = static_cast<double>(index);
  for (std::size_t index = 0; index < x.size(); ++index)
    x[index] = static_cast<double>(index) * configuration.Lx /
               static_cast<double>(configuration.Nx);
  for (std::size_t index = 0; index < y.size(); ++index)
    y[index] = static_cast<double>(index) * configuration.Ly /
               static_cast<double>(configuration.Ny);
  for (std::size_t index = 0; index < z.size(); ++index)
    z[index] =
        -configuration.Lz + static_cast<double>(index) * configuration.Lz /
                                static_cast<double>(configuration.Nz - 1);
  for (const auto &coordinate :
       std::array<std::pair<const char *, const std::vector<double> *>, 5>{
           {{"j", &j}, {"kl", &kl}, {"x", &x}, {"y", &y}, {"z", &z}}}) {
    const auto result =
        writeDoubles(root, coordinate.first, *coordinate.second, "/");
    if (!result)
      return result;
  }
  for (const auto &scalar : std::array<std::pair<const char *, double>, 10>{
           {{"Lx", configuration.Lx},
            {"Ly", configuration.Ly},
            {"Lz", configuration.Lz},
            {"N0", configuration.N0},
            {"g", configuration.g},
            {"latitude", configuration.latitude},
            {"planetaryRadius", configuration.planetaryRadius},
            {"rho0", configuration.rho0},
            {"rotationRate", configuration.rotationRate},
            {"t0", checkpoint.state.t0}}}) {
    const auto result = writeDouble(root, scalar.first, scalar.second, "/");
    if (!result)
      return result;
  }
  auto result =
      writeLogical(root, "isHydrostatic", configuration.isHydrostatic, "/");
  if (!result)
    return result;
  result =
      writeLogical(root, "shouldAntialias", configuration.shouldAntialias, "/");
  if (!result)
    return result;
  for (std::size_t index = 0; index < forcingEntries.size(); ++index) {
    const std::string path =
        forcingEntries.size() == 1
            ? "/forcing"
            : "/forcing/forcing-" + std::to_string(index + 1);
    result =
        writeForcingEntry(forcingGroups[index], *forcingEntries[index], path);
    if (!result)
      return result;
  }
  return WVCheckpointStatus::ok();
}

} // namespace wavevortex::runtime::detail
