# SPDX-License-Identifier: LicenseRef-Azmuth-Proprietary
# Copyright (c) 2026 Kiransekar. All rights reserved.
"""
Golden model for SNN unit - reference implementation for co-simulation
"""

import numpy as np


class SNNReferenceModel:
    def __init__(self, num_neurons: int = 256, learning_rate: float = 0.01):
        self.num_neurons = num_neurons
        self.learning_rate = learning_rate
        # Initialize random weights for demo
        self.weights = np.random.rand(num_neurons, 64).astype(np.float32)  # 256 neurons x 64 inputs
        self.neuron_states = np.zeros(num_neurons, dtype=np.float32)

    def lif_neuron(self, inputs: np.ndarray, weights: np.ndarray,
                   leak_rate: float = 0.1, threshold: float = 1.0) -> Tuple[np.ndarray, np.ndarray]:
        """
        Leaky Integrate-and-Fire neuron model
        Returns: (spikes, new_states)
        """
        # Compute weighted sum
        weighted_sum = np.dot(weights, inputs)

        # Update neuron states with leak
        self.neuron_states = self.neuron_states * (1 - leak_rate) + weighted_sum

        # Generate spikes where state exceeds threshold
        spikes = (self.neuron_states >= threshold).astype(np.int32)

        # Reset states for neurons that spiked
        self.neuron_states = np.where(spikes, 0.0, self.neuron_states)

        return spikes, self.neuron_states.copy()

    def snn_classify(self, spike_input: np.ndarray) -> tuple:
        """
        Reference SNN classification
        spike_input: 64-element array of spike rates
        Returns: (classification, confidence)
        """
        if len(spike_input) != 64:
            raise ValueError("Spike input must be 64 elements")

        # Perform LIF neuron computation
        spikes, _ = self.lif_neuron(spike_input, self.weights)

        # Find neuron with highest activation
        activations = np.sum(spikes)  # Count total spikes
        max_spikes = np.max(spikes) if len(spikes) > 0 else 0

        # Classify based on the most active neuron
        if np.any(spikes):
            class_idx = int(np.argmax(spikes))
            confidence = float(np.sum(spikes) / len(spikes))  # Spike density
        else:
            class_idx = 0
            confidence = 0.0

        return class_idx, min(confidence, 1.0)  # Cap confidence at 1.0

    def train(self, spike_input: np.ndarray, target_class: int):
        """
        Simple STDP-inspired training
        """
        if len(spike_input) != 64:
            raise ValueError("Spike input must be 64 elements")

        # Get current classification
        current_class, _ = self.snn_classify(spike_input)

        # Update weights based on difference from target
        if current_class != target_class:
            # Strengthen weights for target class
            self.weights[target_class, :] += self.learning_rate * spike_input
            # Normalize to prevent weights from growing too large
            self.weights[target_class, :] /= (1 + self.learning_rate)

    def get_weights(self):
        """Return current weights for inspection"""
        return self.weights.copy()


def test_snn_classification():
    """Test the SNN reference model"""
    snn = SNNReferenceModel(num_neurons=256, learning_rate=0.01)

    # Test with sample input
    test_input = np.random.rand(64).astype(np.float32)  # Random 64-element spike pattern

    classification, confidence = snn.snn_classify(test_input)

    print(f"SNN Test Results:")
    print(f"  Input: {test_input[:8]}... (first 8 elements)")
    print(f"  Classification: {classification}")
    print(f"  Confidence: {confidence:.3f}")

    return classification, confidence


if __name__ == "__main__":
    print("SNN Golden Model Test")
    print("=" * 40)

    test_snn_classification()