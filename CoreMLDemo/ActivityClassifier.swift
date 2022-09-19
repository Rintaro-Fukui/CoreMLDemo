//
//  ActivityClassifier.swift
//  CoreMLDemo
//
//  Created by Rintaro Fukui on 2022/09/19.
//

import Foundation
import CoreMotion
import CoreML

class MyActivityClassifier_: ObservableObject {
    
    // CoreMotion
    let motionManager = CMMotionManager()
    
    // ボタンが押されたかを判定する
    @Published var isStarted = false
    
    // 推論結果
    @Published var output: [(String, Double)] = [("None", 0.0), ("None", 0.0)]
    
    // モデルの呼び出し
    static let configuration = MLModelConfiguration()
    let model = try! MyActivityClassifier(configuration: configuration)

    // モデルに入力する特徴量
    // 一定以上(モデルの詳細ページを参照)、値が溜まったら推論して配列を空にする
    static let predictionWindowSize = 100
    var acceleration_x = try! MLMultiArray(
        shape: [predictionWindowSize] as [NSNumber],
        dataType: MLMultiArrayDataType.double)
    var acceleration_y = try! MLMultiArray(
        shape: [predictionWindowSize] as [NSNumber],
        dataType: MLMultiArrayDataType.double)
    var acceleration_z = try! MLMultiArray(
        shape: [predictionWindowSize] as [NSNumber],
        dataType: MLMultiArrayDataType.double)
    var attitude_pitch = try! MLMultiArray(
        shape: [predictionWindowSize] as [NSNumber],
        dataType: MLMultiArrayDataType.double)
    var attitude_roll = try! MLMultiArray(
        shape: [predictionWindowSize] as [NSNumber],
        dataType: MLMultiArrayDataType.double)
    var attitude_yaw = try! MLMultiArray(
        shape: [predictionWindowSize] as [NSNumber],
        dataType: MLMultiArrayDataType.double)
    var rotation_x = try! MLMultiArray(
        shape: [predictionWindowSize] as [NSNumber],
        dataType: MLMultiArrayDataType.double)
    var rotation_y = try! MLMultiArray(
        shape: [predictionWindowSize] as [NSNumber],
        dataType: MLMultiArrayDataType.double)
    var rotation_z = try! MLMultiArray(
        shape: [predictionWindowSize] as [NSNumber],
        dataType: MLMultiArrayDataType.double)
    var currentState = try! MLMultiArray(
        shape: [(400) as NSNumber],
        dataType: MLMultiArrayDataType.double)

    private var predictionWindowIndex = 0

    // データを取得
    func getMotionData(deviceMotion: CMDeviceMotion) {

        if predictionWindowIndex == MyActivityClassifier_.predictionWindowSize {
            return
        }

        // 取得したデータを配列に格納する
        acceleration_x[[predictionWindowIndex] as [NSNumber]] = deviceMotion.userAcceleration.x as NSNumber
        acceleration_y[[predictionWindowIndex] as [NSNumber]] = deviceMotion.userAcceleration.y as NSNumber
        acceleration_z[[predictionWindowIndex] as [NSNumber]] = deviceMotion.userAcceleration.z as NSNumber
        attitude_pitch[[predictionWindowIndex] as [NSNumber]] = deviceMotion.attitude.pitch as NSNumber
        attitude_roll[[predictionWindowIndex] as [NSNumber]] = deviceMotion.attitude.roll as NSNumber
        attitude_yaw[[predictionWindowIndex] as [NSNumber]] = deviceMotion.attitude.yaw as NSNumber
        rotation_x[[predictionWindowIndex] as [NSNumber]] = deviceMotion.rotationRate.x as NSNumber
        rotation_y[[predictionWindowIndex] as [NSNumber]] = deviceMotion.rotationRate.y as NSNumber
        rotation_z[[predictionWindowIndex] as [NSNumber]] = deviceMotion.rotationRate.z as NSNumber

        predictionWindowIndex += 1

        if predictionWindowIndex == MyActivityClassifier_.predictionWindowSize {
            DispatchQueue.global().async {
                self.predict()
                DispatchQueue.main.async {
                    self.predictionWindowIndex = 0
                }
            }
        }
    }

    // 推論
    private func predict() {

        // モデルに入力
        // 入力する特徴量はMLMultiArrayに変換する
        // 入力する特徴量はモデルの詳細ページを参照
        let input = MyActivityClassifierInput(
            acceleration_x: acceleration_x,
            acceleration_y: acceleration_y,
            acceleration_z: acceleration_z,
            attitude_pitch: attitude_pitch,
            attitude_roll: attitude_roll,
            attitude_yaw: attitude_yaw,
            rotation_x: rotation_x,
            rotation_y: rotation_y,
            rotation_z: rotation_z,
            stateIn: currentState)

        // 推論結果を取り出してパーセンテージの高い順にソート
        guard let result = try? model.prediction(input: input) else { return }
        let sorted = result.labelProbability.sorted {
            return $0.value > $1.value
        }
        output = sorted
        print(output)
    }
    
    // スタートボタンを押したときの処理
    func start() {
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 0.1
            motionManager.startDeviceMotionUpdates(to: OperationQueue.current!, withHandler: {
                (motion:CMDeviceMotion?, error:Error?) in
                self.getMotionData(deviceMotion: motion!)
            })
        }
        isStarted = true
    }
    
    // ストップボタンを押したときの処理
    func stop() {
        isStarted = false
        motionManager.stopDeviceMotionUpdates()
    }
}
