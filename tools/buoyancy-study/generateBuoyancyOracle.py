"""Independent 100-digit monomial integration of positive Chebyshev profiles."""
from decimal import Decimal, localcontext
from pathlib import Path
import csv
import math


def chebyshev(n):
    previous, current = [Decimal(1)], [Decimal(0), Decimal(1)]
    if n == 0:
        return previous
    for _ in range(1, n):
        following = [Decimal(0)] + [2 * c for c in current]
        for j, c in enumerate(previous):
            following[j] -= c
        previous, current = current, following
    return current


def evaluate(coefficients, x):
    value = Decimal(0)
    for c in reversed(coefficients):
        value = value * x + c
    return value


def generate(destination):
    rows = []
    exact = Decimal.from_float
    with localcontext() as context:
        context.prec = 100
        for degree in [0, 1, 8, 32, 64, 128]:
            coefficients = [exact(2e-5) * c for c in chebyshev(degree)]
            coefficients[0] += exact(1e-4)
            primitive = [Decimal(0)] + [c / (j + 1) for j, c in enumerate(coefficients)]
            moment = [Decimal(0), Decimal(0)] + [c / (j + 2) for j, c in enumerate(coefficients)]
            cases = [(z, eta) for z in [-999., -750., -500., -1.] for eta in [0., 1e-14, -1e-14, 1e-9, -1e-9, .1, -.1]]
            cases += [(-500., 400.), (-500., -400.), (1., 2.), (-3., -2.), (0., 1e-12), (-1000., 8 * math.ulp(1000.)), (0., -8 * math.ulp(1000.))]
            for z, eta in cases:
                raw_label = z - eta
                label = min(0., max(-1000., raw_label))
                adjustment = label - raw_label
                crest = max(z, 0.)
                interval = (eta - adjustment) - crest
                a = 1 + exact(label) / 500
                b = a + exact(interval) / 500
                xi = 1 + exact(min(0., z)) / 500
                reference = float(evaluate(coefficients, xi))
                integral = 500 * (evaluate(primitive, b) - evaluate(primitive, a))
                triangle = 500 ** 2 * (b * (evaluate(primitive, b) - evaluate(primitive, a)) - evaluate(moment, b) + evaluate(moment, a))
                ape = exact(crest) * integral + triangle
                remainder = integral - exact(reference) * exact(eta)
                rows.append([degree, z, eta, reference, float(-integral), float(ape), float(remainder), float(evaluate(coefficients, a))])
    with destination.open('w', newline='') as handle:
        writer = csv.writer(handle, lineterminator="\n")
        writer.writerow(['degree', 'z', 'eta', 'referenceN2', 'buoyancy', 'ape', 'remainder', 'labelN2'])
        writer.writerows(rows)


if __name__ == '__main__':
    root = Path(__file__).resolve().parents[2]
    generate(root / 'UnitTests/ReferenceImplementations/data/buoyancy-oracle.csv')
