import Intents
import CallKit

class IntentHandler: INExtension, INStartCallIntentHandling {

    private let callController = CXCallController()

    func handle(intent: INStartCallIntent, completion: @escaping (INStartCallIntentResponse) -> Void) {
        guard let contact = intent.contacts?.first,
              let handle = contact.personHandle,
              let phoneNumber = handle.value else {
            completion(INStartCallIntentResponse(code: .failure, userActivity: nil))
            return
        }

        let cxHandle = CXHandle(type: .phoneNumber, value: phoneNumber)
        let action = CXStartCallAction(call: UUID(), handle: cxHandle)
        action.isVideo = (intent.callCapability == .videoCall)

        callController.request(CXTransaction(action: action)) { error in
            DispatchQueue.main.async {
                if error == nil {
                    completion(INStartCallIntentResponse(code: .ready, userActivity: nil))
                } else {
                    completion(INStartCallIntentResponse(code: .continueInApp, userActivity: nil))
                }
            }
        }
    }

    func resolveContacts(for intent: INStartCallIntent,
                         with completion: @escaping ([INStartCallContactResolutionResult]) -> Void) {
        guard let contacts = intent.contacts, !contacts.isEmpty else {
            completion([.unsupported(forReason: .noContactFound)])
            return
        }
        completion(contacts.map { .success(with: $0) })
    }

    func resolveCallCapability(for intent: INStartCallIntent,
                               with completion: @escaping (INStartCallCallCapabilityResolutionResult) -> Void) {
        completion(.success(with: intent.callCapability))
    }
}
