import Foundation
import UIKit

@Observable
final class PruefungsAuftrag {
    var ocrText: String = ""
    var ocrConfidence: Double = 0
    var originalBild: UIImage? = nil
    var mietobjekt: Mietobjekt? = nil

    init() {}
}
