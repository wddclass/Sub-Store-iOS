import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - 参数项模型
struct ParamItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var key: String = ""
    var value: String = ""
    
    init(key: String = "", value: String = "") {
        self.id = UUID()
        self.key = key
        self.value = value
    }
}

// MARK: - 参数编辑器视图
struct ParamsEditorView: View {
    @Binding var parameters: [ParamItem]
    let type: String
    let isVisible: Bool
    
    @State private var keyOccurrences: [String: Int] = [:]
    @State private var showingAddSheet = false
    @FocusState private var focusedField: UUID?
    
    // 本地化文本
    private var optionsText: String {
        return "操作"
    }
    
    private var deleteParamsText: String {
        return "删除"
    }
    
    private var emptyTipsText: String {
        return "暂无参数，点击右上角添加参数"
    }
    
    var body: some View {
        if isVisible {
            VStack(spacing: 0) {
                // 表头
                headerView
                
                // 参数列表
                if parameters.isEmpty {
                    emptyStateView
                } else {
                    parametersList
                }
                
                // 添加按钮
                addButton
            }
            #if canImport(UIKit)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            #else
            .background(Color.gray.opacity(0.1))
            #endif
            .cornerRadius(12)
            .onAppear {
                updateKeyOccurrences()
            }
            .onChange(of: parameters) { _, _ in
                updateKeyOccurrences()
            }
        }
    }
    
    // MARK: - 表头视图
    private var headerView: some View {
        HStack {
            Text("Key")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("Value")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(optionsText)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .frame(width: 60)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        #if canImport(UIKit)
        .background(Color(UIColor.tertiarySystemGroupedBackground))
        #else
        .background(Color.gray.opacity(0.05))
        #endif
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor({
                    #if canImport(UIKit)
                    return Color(UIColor.separator)
                    #else
                    return Color.gray.opacity(0.3)
                    #endif
                }()),
            alignment: .bottom
        )
    }
    
    // MARK: - 参数列表
    private var parametersList: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(parameters.enumerated()), id: \.element.id) { index, parameter in
                parameterRow(parameter: parameter, index: index)
                
                if index < parameters.count - 1 {
                    Divider()
                        .padding(.leading, 16)
                }
            }
        }
    }
    
    // MARK: - 参数行
    private func parameterRow(parameter: ParamItem, index: Int) -> some View {
        HStack(spacing: 12) {
            // Key 输入框
            VStack(alignment: .leading, spacing: 4) {
                TextField("key", text: binding(for: index, keyPath: \.key))
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.caption)
                    .foregroundColor(isDuplicateKey(parameter.key) ? .red : .primary)
                    .focused($focusedField, equals: parameter.id)
                    .onSubmit {
                        trimValue(at: index, keyPath: \.key)
                    }
                
                if isDuplicateKey(parameter.key) && !parameter.key.isEmpty {
                    Text("重复的键名")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                isDuplicateKey(parameter.key) ? 
                Color.red.opacity(0.05) : Color.clear
            )
            .cornerRadius(6)
            
            // Value 输入框
            TextField("value", text: binding(for: index, keyPath: \.value))
                .textFieldStyle(PlainTextFieldStyle())
                .font(.caption)
                .frame(maxWidth: .infinity)
                .focused($focusedField, equals: UUID())
            
            // 删除按钮
            Button(action: {
                deleteParameter(at: index)
            }) {
                Text(deleteParamsText)
                    .font(.caption)
                    .foregroundColor(.accentColor)
            }
            .frame(width: 60)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            isDuplicateKey(parameter.key) ? 
            Color.red.opacity(0.02) : Color.clear
        )
    }
    
    // MARK: - 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.rectangle")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text(emptyTipsText)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - 添加按钮
    private var addButton: some View {
        Button(action: addParameter) {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.caption)
                Text("添加参数")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(.accentColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        #if canImport(UIKit)
        .background(Color(UIColor.tertiarySystemGroupedBackground))
        #else
        .background(Color.gray.opacity(0.05))
        #endif
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor({
                    #if canImport(UIKit)
                    return Color(UIColor.separator)
                    #else
                    return Color.gray.opacity(0.3)
                    #endif
                }()),
            alignment: .top
        )
    }
    
    // MARK: - 方法
    private func binding(for index: Int, keyPath: WritableKeyPath<ParamItem, String>) -> Binding<String> {
        Binding(
            get: {
                guard index < parameters.count else { return "" }
                return parameters[index][keyPath: keyPath]
            },
            set: { newValue in
                guard index < parameters.count else { return }
                parameters[index][keyPath: keyPath] = newValue
            }
        )
    }
    
    private func addParameter() {
        let newParameter = ParamItem()
        parameters.append(newParameter)
        
        // 聚焦到新添加的参数的 key 字段
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            focusedField = newParameter.id
        }
    }
    
    private func deleteParameter(at index: Int) {
        guard index < parameters.count else { return }
        
        _ = withAnimation(.easeOut(duration: 0.3)) {
            parameters.remove(at: index)
        }
    }
    
    private func updateKeyOccurrences() {
        var occurrences: [String: Int] = [:]
        
        for parameter in parameters {
            let trimmedKey = parameter.key.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedKey.isEmpty {
                occurrences[trimmedKey] = (occurrences[trimmedKey] ?? 0) + 1
            }
        }
        
        keyOccurrences = occurrences
    }
    
    private func isDuplicateKey(_ key: String) -> Bool {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedKey.isEmpty && (keyOccurrences[trimmedKey] ?? 0) > 1
    }
    
    private func trimValue(at index: Int, keyPath: WritableKeyPath<ParamItem, String>) {
        guard index < parameters.count else { return }
        
        let trimmedValue = parameters[index][keyPath: keyPath]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        parameters[index][keyPath: keyPath] = trimmedValue
        
        updateKeyOccurrences()
    }
}

// MARK: - 参数编辑器包装视图（带标题）
struct ParamsEditorWrapperView: View {
    @Binding var parameters: [ParamItem]
    let title: String
    let type: String
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题和展开/收起按钮
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // 参数数量指示器
                    if !parameters.isEmpty {
                        Text("\(parameters.count)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.accentColor)
                            .clipShape(Capsule())
                    }
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // 参数编辑器
            ParamsEditorView(
                parameters: $parameters,
                type: type,
                isVisible: isExpanded
            )
        }
        .padding()
        #if canImport(UIKit)
        .background(Color(UIColor.systemGroupedBackground))
        #else
        .background(Color.gray.opacity(0.15))
        #endif
        .cornerRadius(12)
    }
}

// MARK: - 键值对编辑器（通用组件）
struct KeyValueEditorView: View {
    @Binding var keyValuePairs: [String: String]
    let title: String
    let keyPlaceholder: String
    let valuePlaceholder: String
    
    @State private var items: [ParamItem] = []
    
    var body: some View {
        ParamsEditorWrapperView(
            parameters: $items,
            title: title,
            type: "generic"
        )
        .onAppear {
            loadItemsFromDictionary()
        }
        .onChange(of: items) { _, newItems in
            updateDictionaryFromItems(newItems)
        }
        .onChange(of: keyValuePairs) { _, _ in
            loadItemsFromDictionary()
        }
    }
    
    private func loadItemsFromDictionary() {
        items = keyValuePairs.map { key, value in
            ParamItem(key: key, value: value)
        }
    }
    
    private func updateDictionaryFromItems(_ newItems: [ParamItem]) {
        var newDictionary: [String: String] = [:]
        
        for item in newItems {
            let trimmedKey = item.key.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedKey.isEmpty {
                newDictionary[trimmedKey] = item.value
            }
        }
        
        keyValuePairs = newDictionary
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            ParamsEditorWrapperView(
                parameters: .constant([
                    ParamItem(key: "timeout", value: "5000"),
                    ParamItem(key: "retry", value: "3"),
                    ParamItem(key: "timeout", value: "3000") // 重复键演示
                ]),
                title: "自定义参数",
                type: "custom"
            )
            
            KeyValueEditorView(
                keyValuePairs: .constant([
                    "User-Agent": "SubStore/1.0",
                    "Authorization": "Bearer token123"
                ]),
                title: "HTTP 头部",
                keyPlaceholder: "Header Name",
                valuePlaceholder: "Header Value"
            )
        }
        .padding()
    }
    #if canImport(UIKit)
    .background(Color(UIColor.systemBackground))
    #else
    .background(Color.white)
    #endif
}