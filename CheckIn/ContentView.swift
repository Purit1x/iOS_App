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
    @State private var showFullScreenImage = false
    @State private var checkInScale: CGFloat = 1.0
    @State private var isRefreshing = false
    
    @FetchRequest(
        entity: CheckInRecord.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \CheckInRecord.timestamp, ascending: false)],
        animation: .spring(response: 0.3))
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
                            .contentTransition(.opacity)
                            .listRowSeparator(.hidden)
                            .listRowBackground(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(UIColor.secondarySystemBackground))
                                    .padding(.vertical, 4)
                            )
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
                                withAnimation {
                                    isRefreshing = true
                                    locationManager.refreshLocation()
                                }
                            }) {
                                Image(systemName: "arrow.clockwise")
                                    .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                                    .animation(
                                        isRefreshing ? 
                                            .linear(duration: 1)
                                            .repeatForever(autoreverses: false) : 
                                            .default,
                                        value: isRefreshing
                                    )
                            }
                        }
                    } else if let location = locationManager.location {
                        VStack {
                            HStack {
                                VStack(alignment: .leading) {
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
                                
                                Spacer()
                                
                                Button(action: {
                                    withAnimation {
                                        isRefreshing = true
                                        locationManager.refreshLocation()
                                    }
                                }) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 16))
                                        .foregroundColor(.blue)
                                        .padding(8)
                                        .background(Color(UIColor.systemBackground))
                                        .clipShape(Circle())
                                        .shadow(radius: 2)
                                        .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                                        .animation(
                                            isRefreshing ? 
                                                .linear(duration: 1)
                                                .repeatForever(autoreverses: false) : 
                                                .default,
                                            value: isRefreshing
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                } header: {
                    Text("当前位置")
                }
                .onChange(of: locationManager.location) { oldValue, newValue in
                    if newValue != nil {
                        withAnimation {
                            isRefreshing = false
                        }
                    }
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
                                .shadow(radius: 2)
                                .overlay(
                                    Button(action: {
                                        withAnimation(.spring(response: 0.3)) {
                                            selectedPhotoData = nil
                                        }
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(.white)
                                            .shadow(radius: 2)
                                    }
                                    .padding(8),
                                    alignment: .topTrailing
                                )
                                .onTapGesture {
                                    showFullScreenImage = true
                                }
                                .transition(.scale.combined(with: .opacity))
                        } else {
                            Button(action: {
                                showingImagePicker = true
                            }) {
                                VStack {
                                    Image(systemName: "photo.on.rectangle")
                                        .font(.system(size: 40))
                                        .foregroundColor(.secondary)
                                    Text("从相册选择")
                                        .font(.callout)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 120)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.secondary.opacity(0.2), lineWidth: 2)
                                        .background(Color(UIColor.secondarySystemBackground))
                                )
                            }
                            .buttonStyle(.plain)
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .animation(.spring(response: 0.3), value: selectedPhotoData)
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
                            checkInScale = 0.95
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
                    .scaleEffect(checkInScale)
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
                    // 2秒后重置按钮状态
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            showCheckInSuccess = false
                            checkInScale = 1.0
                        }
                    }
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(selectedImage: $selectedPhotoData, sourceType: .photoLibrary)
            }
            .fullScreenCover(isPresented: $showFullScreenImage) {
                ZStack {
                    Color.black.ignoresSafeArea()
                    if let imageData = selectedPhotoData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .transition(.opacity)
                    }
                    
                    Button(action: {
                        withAnimation {
                            showFullScreenImage = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
    
    private func performCheckIn() {
        guard let location = locationManager.location else {
            showingLocationError = true
            isCheckingIn = false
            checkInScale = 1.0
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
                
                // 添加成功动画序列
                withAnimation(.spring(response: 0.3)) {
                    isCheckingIn = false
                    showCheckInSuccess = true
                }
                
                // 添加成功反馈
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                
                // 清空表单动画
                withAnimation(.easeInOut(duration: 0.3).delay(0.5)) {
                    notes = ""
                    selectedPhotoData = nil
                }
                
            } catch {
                let nsError = error as NSError
                print("签到保存失败: \(nsError)")
                isCheckingIn = false
                checkInScale = 1.0
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
    
    private var formattedDate: String {
        if let timestamp = record.timestamp {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy年MM月dd日 HH:mm"
            return formatter.string(from: timestamp)
        }
        return "未知时间"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(record.locationName ?? "未知位置")
                .font(.headline)
            Text(formattedDate)
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
    
    private var formattedDate: String {
        if let timestamp = record.timestamp {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy年MM月dd日 HH:mm"
            return formatter.string(from: timestamp)
        }
        return "未知时间"
    }
    
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
                Text(formattedDate)
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
                
                Button {
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("返回上一页")
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
                
                Text(formattedDate)
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
                    Text("度：\(String(format: "%.6f", record.longitude))")
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
