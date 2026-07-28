#if os(macOS)
import CoreMIDI
import Foundation
import DoricoBridgeCore

@MainActor
final class VirtualMIDI {
    private var client = MIDIClientRef()
    private var source = MIDIEndpointRef()
    private(set) var isReady = false

    func start() {
        guard !isReady else { return }
        let clientStatus = MIDIClientCreateWithBlock("Dorico Xbox Bridge" as CFString, &client) { _ in }
        guard clientStatus == noErr else { return }
        let sourceStatus = MIDISourceCreate(client, "Dorico Xbox Bridge" as CFString, &source)
        isReady = sourceStatus == noErr
    }

    func sendPulse(_ address: MIDIAddress, velocity: UInt8 = 100) {
        guard isReady else { return }
        let channel = (address.channel - 1) & 0x0F
        send([0x90 | channel, address.note, velocity])
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(45))
            self?.send([0x80 | channel, address.note, 0])
        }
    }

    func sendControlChange(channel: UInt8, controller: UInt8, value: UInt8) {
        let safeChannel = (min(16, max(1, channel)) - 1) & 0x0F
        send([0xB0 | safeChannel, min(127, controller), min(127, value)])
    }

    private func send(_ bytes: [UInt8]) {
        var packetList = MIDIPacketList()
        withUnsafeMutablePointer(to: &packetList) { listPointer in
            let packet = MIDIPacketListInit(listPointer)
            bytes.withUnsafeBufferPointer { buffer in
                guard let base = buffer.baseAddress else { return }
                _ = MIDIPacketListAdd(listPointer, MemoryLayout<MIDIPacketList>.size, packet, 0, bytes.count, base)
            }
            MIDIReceived(source, listPointer)
        }
    }

    deinit {
        if source != 0 { MIDIEndpointDispose(source) }
        if client != 0 { MIDIClientDispose(client) }
    }
}
#endif
