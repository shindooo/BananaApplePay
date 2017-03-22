//
//  ViewController.swift
//  BananaapplePay
//
//  Created by T.Shindou. on 2017/03/11.
//  Copyright © 2017年 T.Shindou. All rights reserved.
//

import UIKit
import PassKit
import PAYJP

class ViewController: UIViewController, PKPaymentAuthorizationViewControllerDelegate {
    
    @IBOutlet var itemImageView: UIImageView!
    @IBOutlet var amountLabel: UILabel!
    
    // Apple Payボタン
    private lazy var paymentButton: PKPaymentButton = self.createPaymentButton()
    
    private var didPaymentSucceed = false
    
    // サポートするカードの種類
    private var paymentNetworksToSupport: [PKPaymentNetwork] {
        get {
            if #available(iOS 10.0, *) {
                return PKPaymentRequest.availableNetworks()
            } else {
                return [ .masterCard, .amex ]
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Apple Payボタンをビューに追加
        view.addSubview(paymentButton)
        
        // Auto Layout
        paymentButton.heightAnchor.constraint(equalToConstant: 53.0).isActive = true
        paymentButton.widthAnchor.constraint(equalTo: itemImageView.widthAnchor, constant: -24.0).isActive = true
        paymentButton.topAnchor.constraint(equalTo: amountLabel.bottomAnchor, constant: 25.0).isActive = true
        paymentButton.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -40.0).isActive = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !isApplePayAvailable() {
            // Apple Payに対応してなければApple Payボタンを表示してはいけない
            paymentButton.isHidden = true
            
        } else if !isPaymentNetworksAvailable() {
            // サポート対象のカードをユーザーが登録していない
            paymentButton.isHidden = true
            // カードの設定を促す
            showSetupPrompt()
            
        } else {
            paymentButton.isHidden = false
        }
    }
    
    // Apple Payボタンタップ
    func paymentBUttonTapped() {
        let merchantIdentifier = "Appleのサイトで登録したマーチャントID"
        
        didPaymentSucceed = false
        
        // 決済の要求を作成
        let paymentRequest = PKPaymentRequest()
        paymentRequest.currencyCode = "JPY" // 通貨
        paymentRequest.countryCode = "JP"   // 国コード
        paymentRequest.merchantIdentifier = merchantIdentifier
        // サポートするカードの種類
        paymentRequest.supportedNetworks = paymentNetworksToSupport
        // プロトコル（3-D Secure必須）
        paymentRequest.merchantCapabilities = PKMerchantCapability.capability3DS
        // 支払いの内訳・合計を設定
        paymentRequest.paymentSummaryItems = getpaymentSummaryItems()
        
        // 要求する請求先の項目（オプション）
        paymentRequest.requiredBillingAddressFields = .postalAddress
        // 要求する配送先の項目（オプション）
        paymentRequest.requiredShippingAddressFields = [.postalAddress, .email]
        // 配送方法（オプション）
        paymentRequest.shippingMethods = getShipingMethods()
        
        // ペイメントシートを表示
        let paymentController = PKPaymentAuthorizationViewController(paymentRequest: paymentRequest)
        paymentController.delegate = self
        present(paymentController, animated: true, completion: nil)
    }
    
    // ユーザーが配送方法を変更したときに呼ばれるデリゲートメソッド
    func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didSelect shippingMethod: PKShippingMethod, completion: @escaping (PKPaymentAuthorizationStatus, [PKPaymentSummaryItem]) -> Void) {
        // 必要に応じて配送料の更新などを行う
        // updateDeliveryCharge(shippingMethod)
        completion(.success, getpaymentSummaryItems())
    }
    
    // ユーザーが配送先を変更したときに呼ばれるデリゲートメソッド
    func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didSelectShippingContact contact: PKContact, completion: @escaping (PKPaymentAuthorizationStatus, [PKShippingMethod], [PKPaymentSummaryItem]) -> Void) {
        // 必要に応じて配送先に対する入力チェックなどを行う
        // if isValidContact(contact) {
        //     completion(.success, getShipingMethods(), getpaymentSummaryItems())
        // } else {
        //    completion(.invalidShippingContact, getShipingMethods(), getpaymentSummaryItems())
        // }
        completion(.success, getShipingMethods(), getpaymentSummaryItems())
    }
    
    
    // ユーザーが支払いを承認した（Touch IDまたはパスコードの入力）ときに呼ばれるデリゲートメソッド
    func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didAuthorizePayment payment: PKPayment, completion: @escaping (PKPaymentAuthorizationStatus) -> Void) {

        // 受け取ったトークンを使って決済プラットフォームと連携し、決済処理を行う
        // 原則として決済プラットフォームが提供するSDKを用いる
        // ここでは参考までにPAY.JPを利用する場合の処理を記述する
        // ↓↓↓
        let PAYJPPublicKey = "PAY.JPの設定画面で確認した公開鍵"
        
        let apiClient = PAYJP.APIClient(publicKey: PAYJPPublicKey)
        // Apple PayのペイメントトークンからPAY.JPのトークンを作成
        apiClient.createToken(with: payment.token) { (result) in
            switch result {
            case .success(let token):
                // PAY.JPのトークン作成成功
                
                // 決済処理はバックエンド側で行う
                var request = URLRequest(url: URL(string: "https://paymentBackEnd.Example.com/bananaapplepay/api/orders/")!)
                
                request.httpMethod = "POST"
                request.httpBody = "token=\(token.identifer)&amount=\(self.getAmount())&email=\(payment.shippingContact?.emailAddress ?? "")".data(using: .utf8)
                
                let task = URLSession.shared.dataTask(with: request, completionHandler: { (data, response, error) in
                    if let error = error {
                        print("error: \(error.localizedDescription)")
                        completion(.failure)
                        return
                    }
                    
                    guard let httpResponse = response as? HTTPURLResponse  else {
                        completion(.failure)
                        return
                    }
                    
                    if 200...299 ~= httpResponse.statusCode {
                        // 決済処理が正常に完了
                        self.didPaymentSucceed = true
                        completion(.success)
                        
                    } else {
                        print("error: \(data!)")
                        completion(.failure)
                    }
                })
                
                task.resume()
                
            case .failure(let error):
                // PAY.JPのトークン作成失敗
                print("error: \(error.localizedDescription)")
                completion(.failure)
            }
        }
        // ↑↑↑
        // 決済プラットフォームとの連携処理ここまで
    }
    
    // 支払いの承認処理が終了したときに呼ばれるデリゲートメソッド
    func paymentAuthorizationViewControllerDidFinish(_ controller: PKPaymentAuthorizationViewController) {
        // ペイメントシートを閉じる
        controller.dismiss(animated: true,completion: nil)
        
        if didPaymentSucceed {
            performSegue(withIdentifier:"ThankYou", sender: self)
        }
    }
    
    @IBAction func backFromThanYou(segue: UIStoryboardSegue) {
    }
    
    // Apple Payボタンを作成
    private func createPaymentButton() -> PKPaymentButton {
        // Apple Payボタン作成
        let button = PKPaymentButton(type: .plain, style: .black)
        // (Auto Layoutのため)
        button.translatesAutoresizingMaskIntoConstraints = false
        // アクション設定
        button.addTarget(self, action: #selector(ViewController.paymentBUttonTapped), for: .touchUpInside)
        
        return button
    }
    
    // デバイスがApple Payをサポートしているかどうか
    private func isApplePayAvailable() -> Bool {
        // 引数なしのcanMakePaymentsメソッドで、デバイスがApple Payをサポートしているか確認できる
        return PKPaymentAuthorizationViewController.canMakePayments()
    }
    
    // サポート対象のカードが登録されているかどうか
    private func isPaymentNetworksAvailable() -> Bool {
        // PKPaymentNetworkの配列を引数に取るcanMakePaymentsメソッドで、引数の種類のカードをユーザーが登録しているか確認できる
        return PKPaymentAuthorizationViewController.canMakePayments(usingNetworks: paymentNetworksToSupport)
    }
    
    // カードの設定を促す
    private func showSetupPrompt() {
        let alert = UIAlertController(
            title: "利用できるカードが登録されていません",
            message: "カードを登録しますか？",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "はい", style: UIAlertActionStyle.default, handler: { action in
            // カードの設定画面（Walletアプリ）を開く
            PKPassLibrary().openPaymentSetup()
        }))
        alert.addAction(UIAlertAction(title: "いいえ", style: UIAlertActionStyle.cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    private func getAmount() -> NSDecimalNumber {
        return 55;
    }
    
    private func getpaymentSummaryItems() -> [PKPaymentSummaryItem] {
        // 商品価格・送料・割引額など、表示する支払いの内容を設定
        let item = PKPaymentSummaryItem(label: "バナナ", amount: NSDecimalNumber(string: "50"))
        let deliveryCharge = PKPaymentSummaryItem(label: "配送料", amount: 5)
        
        // 総額には会社名をセット（ref. https://developer.apple.com/reference/passkit/pkpaymentrequest/1619231-paymentsummaryitems）
        let total = PKPaymentSummaryItem(label: "(株)ゴリラのバナナ屋", amount: getAmount())
        
        // ※配列の最後のアイテムが総額として設定される
        return [item, deliveryCharge, total]
    }
    
    private func getShipingMethods() -> [PKShippingMethod] {
        // 配送方法の配列
        let shippingMethods = [PKShippingMethod(label: "黒い猫", amount: 50)]
        shippingMethods[0].identifier = "BlackCat"
        shippingMethods[0].detail = "詳細"
        
        return shippingMethods
    }
}
