import Combine
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var store = StudyStore()
    @StateObject private var floatingWindowManager = FloatingWindowManager()
    private let minuteTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationSplitView {
            StudySidebar(now: store.now, mode: store.mode, completion: store.completion)
                .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 300)
        } detail: {
            DashboardView(
                now: store.now,
                selectedDate: $store.selectedDate,
                mode: $store.mode,
                tasks: store.visibleTasks,
                modules: store.visibleModules,
                onToggleTask: toggleTask,
                onToggleGroup: toggleGroup,
                onEditGroup: { group in
                    store.editingGroup = group
                },
                onAddSubtask: { group in
                    store.editorContext = TaskEditorContext(
                        groupID: group.id,
                        groupTitle: group.title,
                        subject: group.subject,
                        initialDate: store.selectedDate
                    )
                },
                onEditTask: { task in
                    store.editorContext = TaskEditorContext(editing: task)
                },
                onDelete: store.deleteTask
            )
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        floatingWindowManager.toggle(store: store)
                    } label: {
                        Label(
                            floatingWindowManager.isVisible ? "隐藏悬浮便签" : "显示悬浮便签",
                            systemImage: "macwindow.on.rectangle"
                        )
                    }
                    .help(floatingWindowManager.isVisible ? "隐藏悬浮便签" : "显示悬浮便签")

                    Button {
                        store.isAITaskInputPresented = true
                    } label: {
                        Label("AI 拆分长期任务", systemImage: "wand.and.stars")
                    }
                    .help("使用 AI 将长期任务拆成每日任务")

                    Button {
                        store.isImporting = true
                    } label: {
                        Label("导入任务", systemImage: "square.and.arrow.down")
                    }
                    .help("从文本或 JSON 文件导入任务")

                    Button {
                        store.isModuleCreatorPresented = true
                    } label: {
                        Label("添加模块", systemImage: "plus")
                    }
                    .help("添加模块")

                    Button {
                        store.isSettingsPresented = true
                    } label: {
                        Label("AI 设置", systemImage: "gearshape")
                    }
                    .help("设置 API URL、API Key 和模型")

                    Button(role: .destructive) {
                        store.isDeletePlansPresented = true
                    } label: {
                        Label("删除计划", systemImage: "trash")
                    }
                    .help("删除当日计划或所有计划")
                    .disabled(!store.hasAnyPlans)
                }
            }
        }
        .task {
            store.synchronizeSchedule()
        }
        .onChange(of: store.mode) {
            store.synchronizeSchedule()
        }
        .onChange(of: store.selectedDate) {
            store.synchronizeSchedule()
        }
        .onReceive(minuteTimer, perform: store.tick)
        .fileImporter(
            isPresented: $store.isImporting,
            allowedContentTypes: [.plainText, .json],
            allowsMultipleSelection: false,
            onCompletion: store.importTasks
        )
        .sheet(item: $store.editorContext) { context in
            TaskEditorSheet(context: context) { title, minutes, groupTitle, dates, startTime, endTime in
                if let task = context.editingTask {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        store.editTask(
                            task,
                            title: title,
                            minutes: minutes,
                            dates: dates,
                            startTime: startTime,
                            endTime: endTime
                        )
                    }
                } else {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        store.addTask(
                            title: title,
                            minutes: minutes,
                            groupTitle: groupTitle,
                            dates: dates,
                            startTime: startTime,
                            endTime: endTime,
                            context: context
                        )
                    }
                }
            }
        }
        .sheet(isPresented: $store.isModuleCreatorPresented) {
            ModuleCreatorSheet(initialDate: store.selectedDate) { title, dates in
                withAnimation(.easeInOut(duration: 0.35)) {
                    store.addModule(title: title, dates: dates)
                }
            }
        }
        .sheet(item: $store.editingGroup) { group in
            ModuleEditorSheet(group: group) { title, durations in
                store.editModule(
                    groupID: group.id,
                    taskIDs: Set(group.tasks.map(\.id)),
                    title: title,
                    durations: durations
                )
            }
        }
        .sheet(isPresented: $store.isAITaskInputPresented) {
            AITaskInputView(store: store) { project, plan in
                store.applyAIPlan(project: project, plan: plan)
            }
        }
        .sheet(isPresented: $store.isSettingsPresented) {
            SettingsView()
        }
        .alert(item: $store.presentedError) { error in
            Alert(
                title: Text("无法导入任务"),
                message: Text(error.message),
                dismissButton: .default(Text("好"))
            )
        }
        .confirmationDialog(
            "选择删除范围",
            isPresented: $store.isDeletePlansPresented,
            titleVisibility: .visible
        ) {
            Button("删除当日计划", role: .destructive) {
                withAnimation(.easeInOut(duration: 0.35)) {
                    store.deleteAllTasksForSelectedDay()
                }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!store.hasTasksForSelectedDay)

            Button("删除所有计划", role: .destructive) {
                withAnimation(.easeInOut(duration: 0.35)) {
                    store.deleteAllPlans()
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("默认删除当前日期的计划；“删除所有计划”会清空全部日期的任务、模块和 AI 长期计划。此操作不可撤销。")
        }
    }

    private func toggleTask(_ task: StudyTask) {
        let animation: Animation = task.isCompleted
            ? .smooth(duration: 0.5)
            : .snappy(duration: 0.28)
        withAnimation(animation) {
            store.toggleTask(task)
        }
    }

    private func toggleGroup(_ group: TaskGroup) {
        let isCancelling = group.tasks.allSatisfy(\.isCompleted)
        let animation: Animation = isCancelling
            ? .smooth(duration: 0.5)
            : .snappy(duration: 0.28)
        withAnimation(animation) {
            store.toggleGroup(group)
        }
    }
}
