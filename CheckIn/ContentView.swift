//
//  ContentView.swift
//  CheckIn
//
//  Created by 徐乙巽 on 2024/12/18.
//

import SwiftUI
import CoreData
import CoreLocation
import PhotosUI

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var locationManager = LocationManager()
    @State private var notes: String = ""
    @State private var showingLocationError = false
    @FocusState private var isNotesFocused: Bool
    @State private var isCheckingIn = false
    @State private var showCheckInSuccess = false
    @State private var selectedPhotoData: Data?
    @State private var showingImagePicker = false
    
    @FetchRequest(
        entity: CheckInRecord.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \CheckInRecord.timestamp, ascending: false)],
        animation: .default)
    private var checkInRecords: FetchedResults<CheckInRecord>

    var body: some View {
        NavigationSplitView {
            // 侧边栏：签到历史
            List {
                ForEach(checkInRecords) { record in
                    NavigationLink {
                        CheckInDetailView(record: record)
                    } label: {
                        CheckInRowView(record: record)
                    }
                }
            }
            .navigationTitle("签到历史")
            .listStyle(.insetGrouped)
        } detail: {
            // 主要内容：签到界面
            List {
                Section {
                    // 位置信息
                    if locationManager.location == nil {
                        HStack {
                            Text("正在获取位置...")
                                .foregroundColor(.secondary)
                            Spacer()
                            Button(action: {
                                locationManager.refreshLocation()
                            }) {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                    } else if let location = locationManager.location {
                        LabeledContent("经纬度") {
                            Text("\(location.coordinate.latitude), \(location.coordinate.longitude)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        if let placemark = locationManager.placemark {
                            LabeledContent("地点") {
                                Text(placemark.name ?? "未知位置")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("当前位置")
                }
                
                Section {
                    // 照片选择区域
                    HStack {
                        if let imageData = selectedPhotoData, let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    Button(action: {
                                        selectedPhotoData = nil
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.white)
                                            .background(Circle().fill(Color.black.opacity(0.5)))
                                    }
                                    .padding(8),
                                    alignment: .topTrailing
                                )
                        } else {
                            Button(action: {
                                showingImagePicker = true
                            }) {
                                VStack {
                                    Image(systemName: "photo.on.rectangle")
                                        .font(.largeTitle)
                                        .foregroundColor(.secondary)
                                    Text("从相册选择")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 100)
                                .background(Color(UIColor.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                } header: {
                    Text("照片")
                }
                
                Section {
                    // 备注输入区域
                    ZStack(alignment: .topLeading) {
                        if notes.isEmpty {
                            Text("请输入备注...")
                                .foregroundColor(.gray)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 8)
                        }
                        TextEditor(text: $notes)
                            .frame(height: 100)
                            .scrollContentBackground(.hidden)
                            .focused($isNotesFocused)
                    }
                } header: {
                    Text("备注")
                }
                
                Section {
                    // 签到按钮
                    Button(action: {
                        isNotesFocused = false
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            isCheckingIn = true
                        }
                        performCheckIn()
                    }) {
                        HStack {
                            Spacer()
                            if showCheckInSuccess {
                                Image(systemName: "checkmark.circle.fill")
                                    .imageScale(.large)
                                    .transition(.scale.combined(with: .opacity))
                            }
                            Text(showCheckInSuccess ? "签到成功" : "签到")
                                .bold()
                            Spacer()
                        }
                    }
                    .listRowBackground(
                        Group {
                            if showCheckInSuccess {
                                Color.green
                            } else {
                                locationManager.location != nil ? Color.blue : Color.gray
                            }
                        }
                    )
                    .foregroundColor(.white)
                    .disabled(locationManager.location == nil || isCheckingIn)
                    .scaleEffect(isCheckingIn ? 0.95 : 1.0)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("签到")
            .alert("位置服务错误", isPresented: $showingLocationError) {
                Button("确定", role: .cancel) { }
            } message: {
                Text("请确保已启用位置服务")
            }
            .onChange(of: showCheckInSuccess) { oldValue, newValue in
                if newValue {
                    // 2秒后重���按钮状态
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            showCheckInSuccess = false
                        }
                    }
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(selectedImage: $selectedPhotoData, sourceType: .photoLibrary)
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
    
    private func performCheckIn() {
        guard let location = locationManager.location else {
            showingLocationError = true
            isCheckingIn = false
            return
        }
        
        withAnimation {
            let newRecord = CheckInRecord(context: viewContext)
            newRecord.timestamp = Date()
            newRecord.latitude = location.coordinate.latitude
            newRecord.longitude = location.coordinate.longitude
            newRecord.notes = notes
            newRecord.locationName = locationManager.placemark?.name ?? "未知位置"
            newRecord.photo = selectedPhotoData
            
            do {
                try viewContext.save()
                notes = "" // 清空备注
                selectedPhotoData = nil // 清空照片
                
                // 显示成��动画
                withAnimation(.spring(response: 0.3)) {
                    isCheckingIn = false
                    showCheckInSuccess = true
                }
            } catch {
                let nsError = error as NSError
                print("签到保存失败: \(nsError)")
                isCheckingIn = false
            }
        }
    }
}

// MARK: - 子视图

struct LocationStatusCard: View {
    @ObservedObject var locationManager: LocationManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if locationManager.location == nil {
                HStack {
                    Text("正在获取位置...")
                        .foregroundColor(.secondary)
                    Button(action: {
                        locationManager.refreshLocation()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            } else if let location = locationManager.location {
                VStack(alignment: .leading, spacing: 8) {
                    Text("当前位置：")
                        .font(.headline)
                    Text("\(location.coordinate.latitude), \(location.coordinate.longitude)")
                        .font(.subheadline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    if let placemark = locationManager.placemark {
                        Text(placemark.name ?? "未知位置")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - 列表和详情视图

struct CheckInRowView: View {
    let record: CheckInRecord
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(record.locationName ?? "未知位置")
                .font(.headline)
            Text(record.timestamp ?? Date(), style: .date)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct CheckInDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    let record: CheckInRecord
    @State private var showingDeleteAlert = false
    @State private var showingSaveSuccess = false
    
    var body: some View {
        List {
            if let photoData = record.photo, let uiImage = UIImage(data: photoData) {
                Section("照片") {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            
            Section("位置信息") {
                LabeledContent("地点", value: record.locationName ?? "未知位置")
                LabeledContent("经度", value: String(format: "%.6f", record.longitude))
                LabeledContent("纬度", value: String(format: "%.6f", record.latitude))
            }
            
            Section("时间") {
                Text(record.timestamp ?? Date(), style: .date)
            }
            
            if let notes = record.notes, !notes.isEmpty {
                Section("备注") {
                    Text(notes)
                }
            }
            
            Section {
                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("删除此记录")
                    }
                }
                
                Button {
                    saveAsImage()
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("保存为图片")
                    }
                }
            }
        }
        .navigationTitle("签到详情")
        .listStyle(.insetGrouped)
        .alert("确认删除", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                deleteRecord()
            }
        } message: {
            Text("确定要删除这条签到记录吗？此操作不可撤销。")
        }
        .alert("保存成功", isPresented: $showingSaveSuccess) {
            Button("确定", role: .cancel) { }
        } message: {
            Text("签到记录已保存为图片")
        }
    }
    
    private func saveAsImage() {
        // 创建一个包含所有信息的视图
        let shareView = VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("签到记录")
                    .font(.largeTitle)
                    .bold()
                
                Text(record.timestamp ?? Date(), style: .date)
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom)
            
            if let photoData = record.photo, let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("位置信息")
                        .font(.headline)
                    
                    Text("地点：\(record.locationName ?? "未知位置")")
                    Text("经度：\(String(format: "%.6f", record.longitude))")
                    Text("纬度：\(String(format: "%.6f", record.latitude))")
                }
                
                if let notes = record.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("备注")
                            .font(.headline)
                        Text(notes)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        
        // 将视图转换为图片
        let renderer = ImageRenderer(content: shareView)
        renderer.scale = UIScreen.main.scale
        
        if let uiImage = renderer.uiImage {
            // 保存图片到相册
            UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
            showingSaveSuccess = true
        }
    }
    
    private func deleteRecord() {
        viewContext.delete(record)
        
        do {
            try viewContext.save()
            // 删除成功后返回上一页
            dismiss()
        } catch {
            let nsError = error as NSError
            print("删除记录失败: \(nsError)")
        }
    }
}

// MARK: - 图片选择器
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: Data?
    var sourceType: UIImagePickerController.SourceType
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                // 压缩图片以节省存储空间
                if let compressedData = image.jpegData(compressionQuality: 0.5) {
                    parent.selectedImage = compressedData
                }
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}
