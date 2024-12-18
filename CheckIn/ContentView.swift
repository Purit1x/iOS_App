//
//  ContentView.swift
//  CheckIn
//
//  Created by 徐乙巽 on 2024/12/18.
//

import SwiftUI
import CoreData
import CoreLocation

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var locationManager = LocationManager()
    @State private var notes: String = ""
    @State private var showingLocationError = false
    @FocusState private var isNotesFocused: Bool
    
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
                            .navigationTitle("签到详情")
                            .toolbar {
                                Button("在新窗口中打开") {
                                    openInNewWindow(record: record)
                                }
                            }
                    } label: {
                        CheckInRowView(record: record)
                    }
                }
            }
            .navigationTitle("签到历史")
        } detail: {
            // 主要内容：签到界面
            GeometryReader { geometry in
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 20) {
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
                                .padding(.top)
                            }
                            
                            if let location = locationManager.location {
                                VStack(alignment: .leading) {
                                    Text("当前位置：")
                                        .font(.headline)
                                    Text("\(location.coordinate.latitude), \(location.coordinate.longitude)")
                                        .font(.subheadline)
                                    if let placemark = locationManager.placemark {
                                        Text(placemark.name ?? "未知位置")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.top)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("备注")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
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
                                        .background(Color(UIColor.systemBackground))
                                        .focused($isNotesFocused)
                                }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                                .id("notesEditor")
                            }
                            .padding(.horizontal)
                            
                            Button(action: {
                                isNotesFocused = false
                                performCheckIn()
                            }) {
                                Text("签到")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(locationManager.location != nil ? Color.blue : Color.gray)
                                    .cornerRadius(10)
                            }
                            .disabled(locationManager.location == nil)
                            .padding(.horizontal)
                            
                            Spacer(minLength: 20)
                        }
                        .padding(.vertical)
                        .frame(minHeight: geometry.size.height)
                    }
                    .onChange(of: isNotesFocused) { oldValue, newValue in
                        if newValue {
                            withAnimation {
                                proxy.scrollTo("notesEditor", anchor: .center)
                            }
                        }
                    }
                    .scrollDismissesKeyboard(.immediately)
                }
            }
            .navigationTitle("签到")
            .alert("位置服务错误", isPresented: $showingLocationError) {
                Button("确定", role: .cancel) { }
            } message: {
                Text("请确保已启用位置服务")
            }
        }
    }
    
    private func performCheckIn() {
        guard let location = locationManager.location else {
            showingLocationError = true
            return
        }
        
        withAnimation {
            let newRecord = CheckInRecord(context: viewContext)
            newRecord.timestamp = Date()
            newRecord.latitude = location.coordinate.latitude
            newRecord.longitude = location.coordinate.longitude
            newRecord.notes = notes
            newRecord.locationName = locationManager.placemark?.name ?? "未知位置"
            
            do {
                try viewContext.save()
                notes = "" // 清空备注
            } catch {
                let nsError = error as NSError
                print("签到保存失败: \(nsError)")
            }
        }
    }
    
    private func openInNewWindow(record: CheckInRecord) {
        let url = URL(string: "checkin://detail?id=\(record.objectID.uriRepresentation().absoluteString)")!
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}

struct CheckInRowView: View {
    let record: CheckInRecord
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(record.locationName ?? "未知位置")
                .font(.headline)
            Text(record.timestamp ?? Date(), style: .date)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

struct CheckInDetailView: View {
    let record: CheckInRecord
    
    var body: some View {
        List {
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
        }
        .navigationTitle("签到详情")
    }
}
