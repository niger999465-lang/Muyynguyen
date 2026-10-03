import SwiftUI
import UniformTypeIdentifiers

struct PatchManagerView: View {
    @StateObject private var engine = PatchEngine()
    @State private var showAdd = false
    @State private var name = ""
    @State private var targetPath = ""
    @State private var pickedFileURL: URL? = nil
    @State private var showFileImporter = false
    @State private var importErrorMessage: String? = nil

    private var baseTargetDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("TargetAppSandbox")
    }

    private var patchSourcesDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("PatchSources")
    }

    var body: some View {
        NavigationStack {
            VStack {
                statusBanner
                patchList
            }
            .navigationTitle("muyynguyen Patcher")
            .toolbar { mainToolbar }
            .sheet(isPresented: $showAdd) {
                addPatchSheet
            }
        }
    }

    // MARK: - Status banner

    @ViewBuilder
    private var statusBanner: some View {
        if !engine.statusMessage.isEmpty {
            HStack {
                Image(systemName: engine.isError ? "xmark.circle.fill" : "checkmark.circle.fill")
                    .foregroundColor(engine.isError ? .red : .green)
                Text(engine.statusMessage)
                    .font(.caption)
                    .bold()
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(engine.isError ? Color.red.opacity(0.15) : Color.green.opacity(0.15))
            .cornerRadius(8)
            .padding(.horizontal)
        }
    }

    // MARK: - Patch list

    private var patchList: some View {
        List {
            Section("Danh sach Patch") {
                if engine.patches.isEmpty {
                    Text("Chua co patch nao. Bam (+) de them patch moi.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                ForEach($engine.patches) { $patch in
                    patchRow(patch: $patch)
                }
            }
        }
    }

    private func patchRow(patch: Binding<PatchItem>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(patch.wrappedValue.name)
                    .font(.headline)
                Text("Nguon: \(patch.wrappedValue.sourceFileName)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("Dich: \(patch.wrappedValue.targetRelativePath)")
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
            Spacer()
            Toggle("", isOn: patch.isEnabled)
                .labelsHidden()
                .onChange(of: patch.wrappedValue.isEnabled) { _, newValue in
                    togglePatch(patch: patch, isOn: newValue)
                }
        }
    }

    private func togglePatch(patch: Binding<PatchItem>, isOn: Bool) {
        if isOn {
            if !engine.applyPatch(patch.wrappedValue, baseTargetDirectory: baseTargetDirectory) {
                patch.wrappedValue.isEnabled = false
            }
        } else {
            engine.revertPatch(patch.wrappedValue, baseTargetDirectory: baseTargetDirectory)
        }
        engine.savePatches()
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var mainToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: { showAdd = true }) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
            }
        }
    }

    // MARK: - Add patch sheet

    private var addPatchSheet: some View {
        NavigationStack {
            addPatchForm
                .navigationTitle("Tao Patch")
                .toolbar { addPatchToolbar }
                .fileImporter(
                    isPresented: $showFileImporter,
                    allowedContentTypes: [.item],
                    allowsMultipleSelection: false
                ) { result in
                    handleFileImportResult(result)
                }
        }
    }

    private var addPatchForm: some View {
        Form {
            Section("Cau hinh Patch") {
                TextField("Ten patch (VD: Skin VIP)", text: $name)
                TextField("Duong dan dich (VD: Data/mod.dat)", text: $targetPath)
            }
            Section("File nguon") {
                fileSourceButton
                if let err = importErrorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
    }

    private var fileSourceButton: some View {
        Button {
            showFileImporter = true
        } label: {
            HStack {
                Image(systemName: "doc.badge.plus")
                Text(pickedFileURL?.lastPathComponent ?? "Chon file tu thiet bi")
                    .foregroundColor(pickedFileURL == nil ? .secondary : .primary)
            }
        }
    }

    @ToolbarContentBuilder
    private var addPatchToolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Huy") {
                resetAddForm()
                showAdd = false
            }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Them") {
                addPatchFromPickedFile()
            }
            .disabled(name.isEmpty || targetPath.isEmpty || pickedFileURL == nil)
        }
    }

    // MARK: - Actions

    /// Copies the user-picked file into PatchSources immediately on selection,
    /// so "Them" (Add) never fails with a missing-source-file error later.
    private func handleFileImportResult(_ result: Result<[URL], Error>) {
        importErrorMessage = nil
        switch result {
        case .success(let urls):
            guard let picked = urls.first else { return }
            let gotAccess = picked.startAccessingSecurityScopedResource()
            defer { if gotAccess { picked.stopAccessingSecurityScopedResource() } }

            do {
                try FileManager.default.createDirectory(at: patchSourcesDirectory, withIntermediateDirectories: true)
                let destination = patchSourcesDirectory.appendingPathComponent(picked.lastPathComponent)
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.copyItem(at: picked, to: destination)
                pickedFileURL = destination
            } catch {
                importErrorMessage = "Khong the nhap file: \(error.localizedDescription)"
                pickedFileURL = nil
            }
        case .failure(let error):
            importErrorMessage = "Khong the chon file: \(error.localizedDescription)"
            pickedFileURL = nil
        }
    }

    private func addPatchFromPickedFile() {
        guard let source = pickedFileURL, !name.isEmpty, !targetPath.isEmpty else { return }
        engine.addPatch(name: name, sourceFileName: source.lastPathComponent, targetRelativePath: targetPath)
        resetAddForm()
        showAdd = false
    }

    private func resetAddForm() {
        name = ""
        targetPath = ""
        pickedFileURL = nil
        importErrorMessage = nil
    }
}
