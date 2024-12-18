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
    @State private var selectedPhotosData: [Data] = []
    @State private var showingImagePicker = false
    @State private var showFullScreenImage = false
    @State private var checkInScale: CGFloat = 1.0
    @State private var isRefreshing = false
    @State private var selectedImageIndex: Int = 0
    
    private let maxPhotos = 9
    
    @FetchRequest(
        entity: CheckInRecord.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \CheckInRecord.timestamp, ascending: false)],
        animation: .spring(response: 0.3))
    private var checkInRecords: FetchedResults<CheckInRecord>

    var body: some View {
        NavigationSplitView {
            // 侧边栏：打卡历史
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
            .navigationTitle("打卡历史")
            .listStyle(.insetGrouped)
        } detail: {
            // 主要内容：打卡界面
            List {
                Section {
                    // ���信息
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
                    PhotoGridView(
                        selectedPhotosData: selectedPhotosData,
                        maxPhotos: maxPhotos,
                        onDelete: { index in
                            selectedPhotosData.remove(at: index)
                        },
                        onAdd: {
                            showingImagePicker = true
                        },
                        onTap: { index in
                            selectedImageIndex = index
                            showFullScreenImage = true
                        }
                    )
                } header: {
                    Text("照片")
                } footer: {
                    Text("最多可添加\(maxPhotos)张照片")
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
                    // 打卡按钮
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
                            Text(showCheckInSuccess ? "打卡成功" : "打卡")
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
            .navigationTitle("打卡")
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
                ImagePicker(selectedImage: Binding(
                    get: { nil },
                    set: { newValue in
                        if let imageData = newValue {
                            withAnimation {
                                selectedPhotosData.append(imageData)
                            }
                        }
                    }
                ), sourceType: .photoLibrary)
            }
            .fullScreenCover(isPresented: $showFullScreenImage) {
                PhotoPreviewView(
                    selectedPhotosData: selectedPhotosData,
                    selectedImageIndex: $selectedImageIndex,
                    onDismiss: {
                        withAnimation {
                            showFullScreenImage = false
                        }
                    }
                )
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
            
            if !selectedPhotosData.isEmpty {
                do {
                    let combinedData = NSMutableData()
                    var count = UInt32(selectedPhotosData.count)
                    combinedData.append(&count, length: 4)
                    
                    for photoData in selectedPhotosData {
                        var length = UInt32(photoData.count)
                        combinedData.append(&length, length: 4)
                        combinedData.append(photoData)
                    }
                    
                    newRecord.photosData = combinedData as Data
                } catch {
                    print("照片数据处理失败: \(error)")
                }
            }
            
            do {
                try viewContext.save()
                
                withAnimation(.spring(response: 0.3)) {
                    isCheckingIn = false
                    showCheckInSuccess = true
                }
                
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                
                withAnimation(.easeInOut(duration: 0.3).delay(0.5)) {
                    notes = ""
                    selectedPhotosData.removeAll()
                }
                
            } catch {
                let nsError = error as NSError
                print("打卡保存失败: \(nsError)")
                isCheckingIn = false
                checkInScale = 1.0
            }
        }
    }
}

// MARK: - 子视图

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
    @State private var selectedImageIndex: Int = 0
    
    private var formattedDate: String {
        if let timestamp = record.timestamp {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy年MM月dd日 HH:mm"
            return formatter.string(from: timestamp)
        }
        return "未知时间"
    }
    
    private var photos: [Data] {
        guard let photosData = record.photosData else { return [] }
        
        let data = photosData
        var photos: [Data] = []
        
        data.withUnsafeBytes { buffer in
            guard let baseAddress = buffer.baseAddress else { return }
            var offset = 0
            
            let countPtr = baseAddress.assumingMemoryBound(to: UInt32.self)
            let count = Int(countPtr.pointee)
            offset += 4
            
            for _ in 0..<count {
                let lengthPtr = (baseAddress + offset).assumingMemoryBound(to: UInt32.self)
                let length = Int(lengthPtr.pointee)
                offset += 4
                
                let photoData = data.subdata(in: offset..<(offset + length))
                photos.append(photoData)
                offset += length
            }
        }
        
        return photos
    }
    
    var body: some View {
        List {
            if !photos.isEmpty {
                Section("照片") {
                    TabView(selection: $selectedImageIndex) {
                        ForEach(photos.indices, id: \.self) { index in
                            if let uiImage = UIImage(data: photos[index]) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .tag(index)
                            }
                        }
                    }
                    .frame(height: 300)
                    .tabViewStyle(.page)
                    .indexViewStyle(.page(backgroundDisplayMode: .always))
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
        .navigationTitle("打卡详情")
        .listStyle(.insetGrouped)
        .alert("确认删除", isPresented: $showingDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                deleteRecord()
            }
        } message: {
            Text("确定要删除这条打卡记录吗？此操作不可撤销。")
        }
        .alert("保存成功", isPresented: $showingSaveSuccess) {
            Button("确定", role: .cancel) { }
        } message: {
            Text("打卡记录已保存为图片")
        }
    }
    
    private func saveAsImage() {
        let shareView = VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("打卡记录")
                    .font(.largeTitle)
                    .bold()
                
                Text(formattedDate)
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom)
            
            if !photos.isEmpty {
                let columns = photos.count == 1 ? 1 :
                             photos.count == 2 ? 2 :
                             photos.count <= 4 ? 2 :
                             3
                
                let spacing: CGFloat = 12
                let availableWidth = UIScreen.main.bounds.width - 40
                let itemWidth = (availableWidth - (spacing * CGFloat(columns - 1))) / CGFloat(columns)
                
                LazyVGrid(
                    columns: Array(repeating: GridItem(.fixed(itemWidth), spacing: spacing), count: columns),
                    spacing: spacing
                ) {
                    ForEach(photos.prefix(9), id: \.self) { photoData in
                        if let uiImage = UIImage(data: photoData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(
                                    width: itemWidth,
                                    height: photos.count == 1 ? itemWidth * 0.75 : itemWidth
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("位置信息")
                        .font(.headline)
                        .padding(.bottom, 4)
                    
                    Group {
                        Text("地点：\(record.locationName ?? "未知位置")")
                        Text("经度：\(String(format: "%.6f", record.longitude))")
                        Text("纬度：\(String(format: "%.6f", record.latitude))")
                    }
                    .foregroundColor(.secondary)
                }
                
                if let notes = record.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("备注")
                            .font(.headline)
                            .padding(.bottom, 4)
                        Text(notes)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        
        let renderer = ImageRenderer(content: shareView)
        renderer.scale = UIScreen.main.scale
        
        if let uiImage = renderer.uiImage {
            UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
            showingSaveSuccess = true
        }
    }
    
    private func deleteRecord() {
        viewContext.delete(record)
        
        do {
            try viewContext.save()
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

struct PhotoGridView: View {
    let selectedPhotosData: [Data]
    let maxPhotos: Int
    let onDelete: (Int) -> Void
    let onAdd: () -> Void
    let onTap: (Int) -> Void
    let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(selectedPhotosData.indices, id: \.self) { index in
                if let uiImage = UIImage(data: selectedPhotosData[index]) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            Button(action: {
                                withAnimation(.spring(response: 0.3)) {
                                    onDelete(index)
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.white)
                                    .shadow(radius: 2)
                            }
                            .padding(4),
                            alignment: .topTrailing
                        )
                        .onTapGesture {
                            onTap(index)
                        }
                }
            }
            
            if selectedPhotosData.count < maxPhotos {
                Button(action: onAdd) {
                    VStack {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 30))
                            .foregroundColor(.secondary)
                        Text("\(selectedPhotosData.count)/\(maxPhotos)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(height: 100)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
    }
}

struct PhotoPreviewView: View {
    let selectedPhotosData: [Data]
    @Binding var selectedImageIndex: Int
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            TabView(selection: $selectedImageIndex) {
                ForEach(selectedPhotosData.indices, id: \.self) { index in
                    if let uiImage = UIImage(data: selectedPhotosData[index]) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .tag(index)
                    }
                }
            }
            .tabViewStyle(.page)
            
            VStack {
                HStack {
                    Text("\(selectedImageIndex + 1)/\(selectedPhotosData.count)")
                        .foregroundColor(.white)
                        .padding(8)
                        .background(.black.opacity(0.6))
                        .clipShape(Capsule())
                    
                    Spacer()
                    
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                }
                .padding()
                
                Spacer()
            }
        }
    }
}
