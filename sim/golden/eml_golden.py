"""
Golden model for EML unit - reference implementation for co-simulation
"""

import numpy as np


def eml_execute(rs1: float, rs2: float, precision: str = 'bf16', complex_mode: bool = False) -> float:
    """
    Reference EML operation: exp(rs1) - ln(rs2)
    """
    # Convert to appropriate precision
    if precision == 'bf16':
        rs1 = to_bf16(rs1)
        rs2 = to_bf16(rs2)

    # Golden model computation
    exp_result = np.exp(rs1)
    ln_result = np.log(rs2) if rs2 > 0 else 0.0  # Prevent log(0)
    result = exp_result - ln_result

    # Apply complex mode if enabled
    if complex_mode:
        # For complex numbers: use Euler's formula as needed
        # For now just return the real part
        pass

    # Clamp to precision
    if precision == 'bf16':
        result = to_bf16(result)

    return result


def to_bf16(val: float) -> float:
    """Convert to Brain Floating Point 16 format"""
    # Convert to float32 first, then truncate mantissa to 7 bits
    f32 = np.float32(val)
    # Extract binary representation
    bits = np.frombuffer(f32.tobytes(), dtype=np.uint32)[0]
    # Keep sign (1 bit), exponent (8 bits), truncate mantissa to 7 bits
    # Clear the lower 16 bits of mantissa (keeping only upper 7 bits)
    bf16_bits = (bits & 0xFFFF0000) | ((bits >> 16) & 0xFFFF)
    # Convert back to float32 by shifting mantissa back
    truncated_bits = (bits & 0xFFFF8000)  # Keep sign, exp, 7 mantissa bits
    bf16_bytes = int(truncated_bits).to_bytes(4, byteorder='little')
    return np.frombuffer(bf16_bytes, dtype=np.float32)[0]


def test_vectors():
    """Test vectors for EML validation"""
    vectors = [
        # Test case: eml_exec(1.0, 1.0) => exp(1) - ln(1) = e - 0 = e ≈ 2.718
        {"rs1": 1.0, "rs2": 1.0, "expected": np.exp(1.0)},  # ≈ 2.71828

        # Test case: eml_exec(0.0, 1.0) => exp(0) - ln(1) = 1 - 0 = 1.0
        {"rs1": 0.0, "rs2": 1.0, "expected": 1.0},

        # Test case: eml_exec(2.0, 2.0) => exp(2) - ln(2) ≈ 7.389 - 0.693 = 6.696
        {"rs1": 2.0, "rs2": 2.0, "expected": np.exp(2.0) - np.log(2.0)},

        # Test case: eml_exec(-1.0, 2.0) => exp(-1) - ln(2) ≈ 0.368 - 0.693 = -0.325
        {"rs1": -1.0, "rs2": 2.0, "expected": np.exp(-1.0) - np.log(2.0)},

        # Test case: eml_exec(0.5, 0.5) => exp(0.5) - ln(0.5) ≈ 1.649 - (-0.693) = 2.342
        {"rs1": 0.5, "rs2": 0.5, "expected": np.exp(0.5) - np.log(0.5)},
    ]

    return vectors


if __name__ == "__main__":
    print("EML Golden Model Test")
    print("=" * 40)

    vectors = test_vectors()

    for i, test in enumerate(vectors):
        rs1, rs2 = test["rs1"], test["rs2"]
        expected = test["expected"]
        result = eml_execute(rs1, rs2)

        print(f"Test {i+1}: eml({rs1}, {rs2})")
        print(f"  Expected: {expected:.6f}")
        print(f"  Result:   {result:.6f}")
        print(f"  Diff:     {abs(expected - result):.8f}")

        # Check if within BF16 tolerance (±1 LSB)
        # For BF16, the tolerance depends on the magnitude of the number
        max_diff = 2 ** (np.floor(np.log2(max(abs(expected), abs(result)))) - 7) if max(abs(expected), abs(result)) > 0 else 1e-6
        success = abs(expected - result) <= max_diff
        print(f"  Status:   {'PASS' if success else 'FAIL'}")
        print()