#include "WaveVortexRuntime/WVObservation.hpp"

#include <cstdlib>
#include <iostream>
#include <string>
#include <vector>

using namespace wavevortex::runtime;

namespace {

void require(bool condition, const char *message) {
  if (!condition) {
    std::cerr << message << '\n';
    std::exit(1);
  }
}

WVObservationSchema schema() {
  WVObservationSchema result;
  result.identifier = "test-observation-v1";
  result.axes = {{"profile", "profile", WVObservationAxisKind::unlimited, 0,
                  WVObservationCoordinateRole::profile},
                 {"sample", "sample", WVObservationAxisKind::unlimited, 0,
                  WVObservationCoordinateRole::identifier},
                 {"bin", "depth_bin", WVObservationAxisKind::fixed, 2,
                  WVObservationCoordinateRole::depth}};
  result.variables = {
      {"profile-count", "profile_sample_count",
       WVObservationScalarType::integer64, {"profile"},
       WVObservationValueLayout::flat, "1", "samples in each profile", {},
       WVObservationCoordinateRole::none,
       WVObservationRaggedRole::rowCount, "sample"},
      {"sample-time", "sample_time", WVObservationScalarType::real64,
       {"sample"}, WVObservationValueLayout::flat, "s", "sample time", {},
       WVObservationCoordinateRole::sampleTime,
       WVObservationRaggedRole::none, {}},
      {"sample-x", "sample_x", WVObservationScalarType::real64, {"sample"},
       WVObservationValueLayout::flat, "m", "sample x", {},
       WVObservationCoordinateRole::x, WVObservationRaggedRole::none, {}},
      {"sample-bin", "sample_bin", WVObservationScalarType::complex64,
       {"bin", "sample"}, WVObservationValueLayout::flat, "m s-1",
       "complex binned sample", {}, WVObservationCoordinateRole::none,
       WVObservationRaggedRole::none, {}},
      {"quality", "quality", WVObservationScalarType::boolean8, {"sample"},
       WVObservationValueLayout::flat, "1", "quality flag", {},
       WVObservationCoordinateRole::none, WVObservationRaggedRole::none, {}},
      {"label", "profile_label", WVObservationScalarType::text, {"profile"},
       WVObservationValueLayout::flat, "", "profile label", {},
       WVObservationCoordinateRole::none, WVObservationRaggedRole::none, {}},
      {"event-id", "event_id", WVObservationScalarType::integer64, {},
       WVObservationValueLayout::record, "1", "event identifier", {},
       WVObservationCoordinateRole::none, WVObservationRaggedRole::none, {}}};
  return result;
}

WVObservationBatch batch() {
  static const double times[] = {1.0, 2.0, 3.0};
  static const wavevortex::WVComplex64 bins[] = {
      {1.0, -1.0}, {2.0, -2.0}, {3.0, -3.0},
      {4.0, -4.0}, {5.0, -5.0}, {6.0, -6.0}};
  WVObservationBatch result;
  result.schemaIdentifier = "test-observation-v1";
  result.values.push_back(WVObservationValue::ownInteger(
      "profile-count", {2}, std::vector<std::int64_t>{1, 2}));
  result.values.push_back(
      WVObservationValue::borrowReal("sample-time", {3}, times));
  result.values.push_back(WVObservationValue::ownReal(
      "sample-x", {3}, std::vector<double>{4.0, 5.0, 6.0}));
  result.values.push_back(
      WVObservationValue::borrowComplex("sample-bin", {2, 3}, bins));
  result.values.push_back(WVObservationValue::ownBoolean(
      "quality", {3}, std::vector<std::uint8_t>{1, 0, 1}));
  result.values.push_back(WVObservationValue::ownText(
      "label", {2}, std::vector<std::string>{"pass-a", "pass-b"}));
  result.values.push_back(WVObservationValue::ownInteger(
      "event-id", {}, std::vector<std::int64_t>{7}));
  return result;
}

} // namespace

int main() {
  const auto declaration = schema();
  require(static_cast<bool>(validateObservationSchema(declaration)),
          "valid observation schema was rejected");
  auto values = batch();
  require(static_cast<bool>(validateObservationBatch(declaration, values)),
          "valid mixed typed/ragged observation batch was rejected");
  require(values.values[1].ownership ==
              WVObservationBufferOwnership::borrowed &&
              values.values[2].ownership == WVObservationBufferOwnership::owned,
          "observation buffer ownership was not explicit");
  require(values.metrics().liveBytes > 0 &&
              values.metrics().retainedStorageBytes > 0,
          "observation batch storage metrics were not reported");
  std::vector<std::uint8_t> manifest;
  require(static_cast<bool>(
              encodeObservationSchemaManifest(declaration, manifest)) &&
              !manifest.empty(),
          "observation schema manifest was not encoded");
  WVObservationSchema decoded;
  require(static_cast<bool>(
              decodeObservationSchemaManifest(manifest, decoded)) &&
              decoded.identifier == declaration.identifier &&
              decoded.axes.size() == declaration.axes.size() &&
              decoded.variables.size() == declaration.variables.size() &&
              decoded.variables[0].raggedRole ==
                  WVObservationRaggedRole::rowCount &&
              decoded.variables[0].raggedChildAxisIdentifier == "sample" &&
              decoded.variables[3].scalarType ==
                  WVObservationScalarType::complex64,
          "observation schema manifest did not preserve its contract");

  auto zero = batch();
  zero.values[0] = WVObservationValue::ownInteger("profile-count", {0}, {});
  zero.values[1] = WVObservationValue::borrowReal("sample-time", {0}, nullptr);
  zero.values[2] = WVObservationValue::ownReal("sample-x", {0}, {});
  zero.values[3] =
      WVObservationValue::borrowComplex("sample-bin", {2, 0}, nullptr);
  zero.values[4] = WVObservationValue::ownBoolean("quality", {0}, {});
  zero.values[5] = WVObservationValue::ownText("label", {0}, {});
  require(static_cast<bool>(validateObservationBatch(declaration, zero)),
          "zero-length observation occurrence was rejected");

  auto inconsistent = batch();
  inconsistent.values[2].extents = {2};
  require(!validateObservationBatch(declaration, inconsistent),
          "inconsistent unlimited extents were accepted");
  auto undeclared = batch();
  undeclared.values.back().variableIdentifier = "undeclared";
  require(!validateObservationBatch(declaration, undeclared),
          "undeclared observation variable was accepted");
  auto malformed = batch();
  malformed.values[0].ownedInteger64 = {2, 2};
  require(!validateObservationBatch(declaration, malformed),
          "malformed ragged row counts were accepted");
  auto drifted = batch();
  drifted.schemaVersion = 2;
  require(!validateObservationBatch(declaration, drifted),
          "observation schema drift was accepted");
  auto badBoolean = batch();
  badBoolean.values[4].ownedBoolean8[1] = 2;
  require(!validateObservationBatch(declaration, badBoolean),
          "invalid Boolean observation value was accepted");

  std::cout << "observation schema/batch tests passed\n";
  return 0;
}
