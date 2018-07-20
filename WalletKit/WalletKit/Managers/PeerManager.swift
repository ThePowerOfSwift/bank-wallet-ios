import Foundation
import RealmSwift

class PeerManager {
    static let shared = PeerManager()

    let walletManager: WalletManager

    private let peer = Peer(network: TestNet())

    init(walletManager: WalletManager = .shared) {
        self.walletManager = walletManager
        peer.delegate = self
    }

    func connect() {
        peer.connect()
    }

    func requestHeaders(headerHashes: [Data]) {
        peer.sendGetHeadersMessage(headerHashes: headerHashes)
    }

}

extension PeerManager: PeerDelegate {

    public func peerDidConnect(_ peer: Peer) {
        let realm = RealmFactory.shared.realm
        let addresses = realm.objects(Address.self)

        peer.load(filters: addresses.map { $0.publicKeyHash })

        do {
            try HeaderSyncer.shared.sync()
        } catch {
            print("HeaderSyncer error: \(error)")
        }

//        let realm = try! Realm()
//        if let lastBlock = realm.objects(Block.self).first {
//            print("Last BLock Hash: \(lastBlock.blockHash)")
//            peer.startSync(filters: addresses.map { $0.publicKeyHash }, latestBlockHash: Data(Data(hex: lastBlock.blockHash)!.reversed()))
//        }
    }

    public func peer(_ peer: Peer, didReceiveMerkleBlockMessage message: MerkleBlockMessage, hash: Data) {
        print("MERKLE BLOCK: \(hash.hex)")

        do {
            try MerkleBlockHandler.shared.handle(message: message)
        } catch {
            print("MerkleBlockHandler error: \(error)")
        }
    }

    public func peer(_ peer: Peer, didReceiveTransaction transaction: TransactionMessage, hash: Data) {
        print("TRANSACTION: \(hash.hex)")
    }

    public func peer(_ peer: Peer, didReceiveHeadersMessage message: HeadersMessage) {
        message.blockHeaders.first.map {
            print("First Header: \(Data(Crypto.sha256sha256($0.serialized()).reversed()).hex)")
        }
        message.blockHeaders.last.map {
            print("Last Header: \(Data(Crypto.sha256sha256($0.serialized()).reversed()).hex)")
        }

        if !message.blockHeaders.isEmpty {
            HeaderHandler.shared.handle(blockHeaders: message.blockHeaders)
        }
    }

}