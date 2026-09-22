import Foundation
import StoreKit

class StoreKitService: ObservableObject {
    @Published var isPro = false
    
    private let proProductID = "com.yangcheben.pro"
    
    func loadProducts() async -> [Product] {
        do {
            let products = try await Product.products(for: [proProductID])
            return products
        } catch {
            print("Failed to load products: \(error)")
            return []
        }
    }
    
    func purchase(product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    isPro = true
                    return true
                case .unverified:
                    return false
                }
            case .userCancelled:
                return false
            case .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            print("Purchase error: \(error)")
            return false
        }
    }
    
    func restorePurchases() async -> Bool {
        do {
            for await result in Transaction.currentEntitlements {
                switch result {
                case .verified(let transaction):
                    if transaction.productID == proProductID {
                        isPro = true
                        return true
                    }
                case .unverified:
                    continue
                }
            }
            return false
        } catch {
            print("Restore error: \(error)")
            return false
        }
    }
}
