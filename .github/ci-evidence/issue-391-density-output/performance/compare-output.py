"""Compare saved NetCDF variables through the same installed C library as the runner."""
import ctypes as C
import json
import math
from pathlib import Path

lib = C.CDLL('/opt/homebrew/Cellar/netcdf/4.9.3/lib/libnetcdf.dylib')
lib.nc_strerror.restype = C.c_char_p

def check(code):
    if code:
        raise RuntimeError(lib.nc_strerror(code).decode())

def ids(function, group):
    count = C.c_int()
    check(function(group, C.byref(count), None))
    values = (C.c_int * count.value)()
    check(function(group, C.byref(count), values))
    return list(values)

def variables(path):
    root = C.c_int()
    check(lib.nc_open(str(path).encode(), 0, C.byref(root)))
    result = {}
    def visit(group, prefix):
        for variable in ids(lib.nc_inq_varids, group):
            name, kind, rank = C.create_string_buffer(257), C.c_int(), C.c_int()
            dims = (C.c_int * 1024)()
            check(lib.nc_inq_var(group, variable, name, C.byref(kind), C.byref(rank), dims, None))
            shape, dimension_names = [], []
            for dimension in dims[:rank.value]:
                size, label = C.c_size_t(), C.create_string_buffer(257)
                check(lib.nc_inq_dim(group, dimension, label, C.byref(size)))
                shape.append(size.value)
                dimension_names.append(label.value.decode())
            size = math.prod(shape)
            full_name = prefix + '/' + name.value.decode()
            if kind.value == 2:  # NC_CHAR
                data = C.create_string_buffer(size)
                check(lib.nc_get_var_text(group, variable, data))
                values = bytes(data.raw)
            elif kind.value == 12:  # NC_STRING
                data = (C.c_char_p * size)()
                check(lib.nc_get_var_string(group, variable, data))
                values = tuple(data)
                check(lib.nc_free_string(C.c_size_t(size), data))
            else:
                assert 1 <= kind.value <= 11, (full_name, kind.value)
                data = (C.c_double * size)()
                check(lib.nc_get_var_double(group, variable, data))
                values = data
            result[full_name] = (kind.value, shape, dimension_names, values)
        for child in ids(lib.nc_inq_grps, group):
            name = C.create_string_buffer(257)
            check(lib.nc_inq_grpname(child, name))
            visit(child, prefix + '/' + name.value.decode())
    try:
        visit(root.value, '')
    finally:
        check(lib.nc_close(root.value))
    return result

def compare(directory):
    rows = []
    coefficient_names = {name + suffix for name in ['Ap', 'Am', 'A0'] for suffix in ['', '_real', '_imag']}
    for family in ['constant', 'hydrostatic', 'boussinesq']:
        baseline = variables(Path(directory) / (family + '-baseline.nc'))
        candidate = variables(Path(directory) / (family + '-candidate.nc'))
        assert baseline.keys() == candidate.keys(), family
        numeric_count, coefficient_count, time_count = 0, 0, 0
        maximum, coefficient_maximum, exact = 0., 0., True
        for name, (kind, shape, dimensions, a) in baseline.items():
            kind_b, shape_b, dimensions_b, b = candidate[name]
            assert (kind, shape, dimensions) == (kind_b, shape_b, dimensions_b), name
            if kind in [2, 12]:
                assert a == b, name
                continue
            numeric_count += 1
            timed = 't' in dimensions
            time_count += timed
            difference, scale = 0., 0.
            equal = True
            for x, y in zip(a, b):
                if timed:
                    assert math.isfinite(x) and math.isfinite(y), name
                if not math.isfinite(x) or not math.isfinite(y):
                    assert (math.isnan(x) and math.isnan(y)) or x == y, name
                    continue
                equal &= x == y
                difference = max(difference, abs(x-y))
                scale = max(scale, abs(x))
            error = difference / max(scale, float.fromhex('0x1.0000000000000p-1022'))
            assert error <= 1e-12, (family, name, error)
            maximum, exact = max(maximum, error), exact and equal
            if timed and name.rsplit('/', 1)[-1] in coefficient_names:
                coefficient_count += 1
                coefficient_maximum = max(coefficient_maximum, error)
        assert coefficient_count >= 3 and time_count > coefficient_count, family
        rows.append(dict(family=family,numericVariableCount=numeric_count,timeDependentVariableCount=time_count,
                         savedCoefficientVariableCount=coefficient_count,maximumNormalizedError=maximum,
                         savedCoefficientMaximumNormalizedError=coefficient_maximum,allNumericVariablesExactlyEqual=exact))
    return rows

if __name__ == '__main__':
    import sys
    rows = compare(sys.argv[1])
    Path(sys.argv[2]).write_text(json.dumps(rows, indent=2) + '\n')
    print(json.dumps(rows, indent=2))
