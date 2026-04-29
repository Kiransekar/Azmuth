#!/usr/bin/env python3
"""
Xcew Processor Post-Silicon Validation Script
"""

import csv
import json
import time
import subprocess
import serial
import struct
from datetime import datetime

class XcewValidator:
    def __init__(self, uart_port="/dev/ttyUSB0", baudrate=115200):
        self.uart = None
        self.port = uart_port
        self.baudrate = baudrate
        self.results = {}

    def connect_uart(self):
        """Connect to the Xcew processor via UART"""
        try:
            self.uart = serial.Serial(self.port, self.baudrate, timeout=1)
            print(f"Connected to Xcew processor on {self.port}")
            return True
        except Exception as e:
            print(f"Failed to connect to UART: {e}")
            return False

    def disconnect_uart(self):
        """Disconnect from UART"""
        if self.uart:
            self.uart.close()
            print("UART disconnected")

    def send_command(self, cmd):
        """Send command to Xcew processor"""
        if self.uart:
            self.uart.write(cmd.encode() + b'\n')
            time.sleep(0.1)
            response = self.uart.readline().decode().strip()
            return response
        return None

    def step1_power_sequence(self):
        """Execute Step 1: Power-on sequence validation"""
        print("=== Step 1: Power-on sequence validation ===")

        # Check if UART responds
        response = self.send_command("HELLO")
        if response and "XCEW" in response.upper():
            print("✓ Processor responded to hello command")
            self.results['step1_hello'] = True
        else:
            print("✗ Processor did not respond to hello command")
            self.results['step1_hello'] = False

        # Check basic register access
        response = self.send_command("READ_CSR 0x7C0")
        if response and "CSR" in response:
            print("✓ CSR register accessible")
            self.results['step1_csr'] = True
        else:
            print("✗ CSR register not accessible")
            self.results['step1_csr'] = False

        return self.results['step1_hello'] and self.results['step1_csr']

    def step2_scan_bist(self):
        """Execute Step 2: Scan chain and BIST validation"""
        print("\n=== Step 2: Scan chain and BIST validation ===")

        # Execute BIST sequence
        response = self.send_command("START_BIST")
        if response and "BIST_STARTED" in response:
            print("✓ BIST started successfully")
            self.results['step2_bist_start'] = True
        else:
            print("✗ BIST start failed")
            self.results['step2_bist_start'] = False

        # Wait for BIST to complete and check results
        time.sleep(2)  # Wait for BIST to complete
        response = self.send_command("BIST_STATUS")
        if response and "PASS" in response:
            print("✓ BIST completed successfully")
            self.results['step2_bist_status'] = True
        else:
            print("✗ BIST failed")
            self.results['step2_bist_status'] = False

        return self.results['step2_bist_start'] and self.results['step2_bist_status']

    def step3_firmware_csr(self):
        """Execute Step 3: Firmware loading and CSR validation"""
        print("\n=== Step 3: Firmware and CSR validation ===")

        # Load firmware command
        response = self.send_command("LOAD_FW test_fw.bin")
        if response and "LOADED" in response:
            print("✓ Firmware loaded successfully")
            self.results['step3_fw_load'] = True
        else:
            print("✗ Firmware load failed")
            self.results['step3_fw_load'] = False

        # Test CSR operations
        csr_tests = [
            ("WRITE_CSR 0x7C0 0x1234", "CSR_WRITE"),
            ("READ_CSR 0x7C0", "CSR_READ"),
            ("WRITE_CSR 0x7C1 0xABCD", "CSR_WRITE"),
            ("READ_CSR 0x7C1", "CSR_READ")
        ]

        csr_success = True
        for cmd, desc in csr_tests:
            response = self.send_command(cmd)
            if response and "OK" in response:
                print(f"✓ {desc} successful")
            else:
                print(f"✗ {desc} failed")
                csr_success = False

        self.results['step3_csr_ops'] = csr_success

        return self.results['step3_fw_load'] and self.results['step3_csr_ops']

    def step4_cosim_validation(self):
        """Execute Step 4: Co-simulation validation"""
        print("\n=== Step 4: Co-simulation validation ===")

        # Run OODA loop test
        response = self.send_command("RUN_OODA 1000")
        if response and "CYCLES:" in response:
            cycles_str = response.split("CYCLES:")[1].split()[0]
            cycles = int(cycles_str)
            # Calculate latency in ms: cycles * 4ns (250MHz)
            latency_ms = (cycles * 4.0) / 1000000.0
            print(f"✓ OODA test completed: {latency_ms:.3f} ms")

            # Check if within ±15% of expected (assuming 8.8ms as expected from sim)
            expected_latency = 8.8  # From co_sim_report.json
            tolerance = expected_latency * 0.15  # 15% tolerance
            min_expected = expected_latency - tolerance
            max_expected = expected_latency + tolerance

            if min_expected <= latency_ms <= max_expected:
                print(f"✓ Latency within tolerance ({min_expected:.3f} - {max_expected:.3f} ms)")
                self.results['step4_latency'] = True
            else:
                print(f"✗ Latency outside tolerance (got: {latency_ms:.3f} ms)")
                self.results['step4_latency'] = False
        else:
            print("✗ OODA test failed")
            self.results['step4_latency'] = False

        # Test EML functionality
        response = self.send_command("TEST_EML")
        if response and "EML_PASS" in response:
            print("✓ EML unit test passed")
            self.results['step4_eml'] = True
        else:
            print("✗ EML unit test failed")
            self.results['step4_eml'] = False

        # Test SNN functionality
        response = self.send_command("TEST_SNN")
        if response and "SNN_PASS" in response:
            print("✓ SNN unit test passed")
            self.results['step4_snn'] = True
        else:
            print("✗ SNN unit test failed")
            self.results['step4_snn'] = False

        return self.results['step4_latency'] and self.results['step4_eml'] and self.results['step4_snn']

    def run_validation(self):
        """Run the complete validation sequence"""
        print(f"Starting Xcew Processor Validation - {datetime.now()}")
        print("="*60)

        # Run all steps
        step1_pass = self.step1_power_sequence()
        step2_pass = self.step2_scan_bist()
        step3_pass = self.step3_firmware_csr()
        step4_pass = self.step4_cosim_validation()

        # Compile results
        overall_pass = step1_pass and step2_pass and step3_pass and step4_pass

        print("\n" + "="*60)
        print("VALIDATION SUMMARY:")
        print(f"  Step 1 (Power/Reset): {'PASS' if step1_pass else 'FAIL'}")
        print(f"  Step 2 (Scan/BIST): {'PASS' if step2_pass else 'FAIL'}")
        print(f"  Step 3 (FW/CSR): {'PASS' if step3_pass else 'FAIL'}")
        print(f"  Step 4 (Co-sim): {'PASS' if step4_pass else 'FAIL'}")
        print(f"  Overall Status: {'PASSED' if overall_pass else 'FAILED'}")
        print("="*60)

        # Save results to file
        with open('validation_results.json', 'w') as f:
            json.dump(self.results, f, indent=2)

        # Update failures_mode.csv with results
        self.update_failures_csv()

        return overall_pass

    def update_failures_csv(self):
        """Update the failures_mode.csv with actual test results"""
        # Read the existing CSV
        rows = []
        with open('failures_mode.csv', 'r') as f:
            reader = csv.DictReader(f)
            for row in reader:
                # Map test results to failure modes
                if 'step1' in row['test_step'].lower() and row['failure_mode'] == 'No_power_rails_stable':
                    row['status'] = 'PASS' if self.results.get('step1_hello', False) else 'FAIL'
                elif 'step1' in row['test_step'].lower() and row['failure_mode'] == 'Invalid_JTAG_ID':
                    row['status'] = 'PASS' if self.results.get('step1_csr', False) else 'FAIL'
                elif 'step2' in row['test_step'].lower() and 'bist' in row['failure_mode'].lower():
                    row['status'] = 'PASS' if self.results.get('step2_bist_status', False) else 'FAIL'
                elif 'step3' in row['test_step'].lower() and row['failure_mode'] == 'CSR_access_failure':
                    row['status'] = 'PASS' if self.results.get('step3_csr_ops', False) else 'FAIL'
                elif 'step4' in row['test_step'].lower() and 'latency' in row['failure_mode'].lower():
                    row['status'] = 'PASS' if self.results.get('step4_latency', False) else 'FAIL'

                rows.append(row)

        # Write back updated CSV
        with open('failures_mode_updated.csv', 'w', newline='') as f:
            fieldnames = ['failure_mode', 'test_step', 'severity', 'detection_method', 'diagnosis_procedure', 'repair_strategy', 'status']
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            for row in rows:
                writer.writerow(row)

def main():
    validator = XcewValidator()

    if validator.connect_uart():
        success = validator.run_validation()
        validator.disconnect_uart()

        if success:
            print("\n🎉 Xcew Processor validation PASSED!")
            exit(0)
        else:
            print("\n❌ Xcew Processor validation FAILED!")
            exit(1)
    else:
        print("\n❌ Could not establish UART connection!")
        exit(1)

if __name__ == "__main__":
    main()