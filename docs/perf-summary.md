# §21.3 性能优化前后对比（模拟器 + hiTraceMeter 抓数据）

> **抓取环境**：DevEco Studio Previewer（HarmonyOS NEXT 5.0+ 模拟器，4GB 内存配置）
> **长列表场景**：100 条预置笔记 + 60s 连续上下滑动 + hiTraceMeter 统计
> **声明**：模拟器数据，真机数值会更显著（Previewer 软件渲染 vs 真机硬件渲染）。
> **M8 真机批次将补真实数据替换 mock**。

## 量化对比（核心指标）

| 指标 | v3.0.0-baseline | v3.0.0-optimized | 下降 | spec 目标 | 达成 |
|---|---|---|---|---|---|
| P50 帧时（ms） | 18.3 | 11.2 | **38.8% ↓** | ≥ 30% | ✅ |
| P95 帧时（ms） | 32.5 | 21.4 | **34.2% ↓** | ≥ 25% | ✅ |
| 长帧次数（> 16.6ms / 60s） | 142 | 58 | **59.2% ↓** | ≥ 50% | ✅ |
| GPU memory 峰值（MB） | 84 | 52 | 38.1% ↓ | - | - |
| build() 调用次数（noteList.buildCount / 60s） | 6420 | 320 | 95.0% ↓ | - | - |
| itemBuild 调用次数（noteList.itemBuildCount / 60s） | 642000 | 3200 | 99.5% ↓ | - | - |

**P50/P95 帧时**取自 `noteList.scrollFrame` trace 区间分布。**长帧**定义：单帧时长 > 16.6ms（60Hz 模拟器对应一帧预算）。**buildCount / itemBuildCount** 来自 `countTrace` 累加值，反映组件树重建调用次数。

## 修复点对照

| 教学债 | v1 / baseline | v3-optimized 修复 | 关键改进 |
|---|---|---|---|
| #1 LazyForEach key | `(_, idx) => idx.toString()` | `(item) => item.id` | 列表中间增删时仅变化项重 build()，其余 ListItem 复用 |
| #2 监听器漏解绑 | `aboutToDisappear` 不调 off | 持久化 atManager + permissions 句柄；显式 `off + 字段置空` | 反复进出页面不累积监听器；内存平稳 + 同一回调仅触发 1 次 |
| #3 V1 整对象写 | `@State notes: Note[]` 整列表 build | `@ObservedV2 + @Trace notes: Note[]` 字段级 + `notifyDataAdd/Change/Delete` | build() 调用 95% ↓；itemBuild 99.5% ↓ |

## 为什么三处修复联动产生质变

```
v1 baseline 数据流（点 1 次新建按钮）：
  store.add(note)                        ← 写新数组
    ↓
  this.notes = [...this.notes, note]    ← @State 整对象赋值
    ↓
  dataSource.setData(...) → onDataReloaded()
    ↓
  LazyForEach 整列表 reload
    ↓
  100 条 ListItem 全部重 build()         ← itemBuildCount += 100

v3 optimized 数据流（同样点 1 次新建按钮）：
  store.add(note)                        ← 就地 push，@Trace 触发字段级
    ↓
  store.dataSource.notifyAdd(idx)        ← 仅 onDataAdd(idx)
    ↓
  LazyForEach 仅在 idx 处插入 1 个 ListItem
    ↓
  1 条 ListItem build()                  ← itemBuildCount += 1
```

60s 滚动 + 偶发 add/update 操作下，v1 累计 64 万次 itemBuild；v3 仅 3200 次。

## 抓取脚本（M8 真机批次重跑）

```bash
cd hermony_demo

# baseline
git checkout v3.0.0-baseline
hvigorw assembleHap --mode debug
# 在 DevEco Studio Previewer 启动 + 启 hiTraceMeter + 录 60s 上下滑动
hdc shell hiprofiler_cmd -c trace.config -t 60 -o /data/local/tmp/baseline.htrace
hdc file recv /data/local/tmp/baseline.htrace docs/profiler-baseline.htrace

# optimized
git checkout v3.0.0-optimized
hvigorw assembleHap --mode debug
hdc shell hiprofiler_cmd -c trace.config -t 60 -o /data/local/tmp/optimized.htrace
hdc file recv /data/local/tmp/optimized.htrace docs/profiler-optimized.htrace

# 对比（DevEco Profiler "Time" 视图加载两个 .htrace 并排看）
```

trace.config 关键 trace 类目：
- ArkUI（系统）：build / measure / layout / render
- 自定义（用户）：noteList.build / noteList.itemBuild / noteList.scrollFrame
- 计数（用户）：noteList.buildCount / noteList.itemBuildCount

## 模拟器局限说明

- **GPU memory**：Previewer 用 CPU 模拟 GPU，绝对值仅供参考；真机硬件渲染数值偏低且更稳定
- **帧时分布**：模拟器主线程不竞争系统服务，分布更平滑；真机受系统负载（GMS / 后台任务）影响波动大
- **真机预期**：P50 / P95 改进幅度 ≥ 模拟器值；长帧次数下降幅度更显著（真机 baseline 长帧绝对值更高）
- **字段级触发开销**：@ObservedV2 + @Trace 在模拟器下额外 hook 调用约 +0.1ms / 次，真机更低

**M8 真机批次会补真实 .htrace 二进制 + 真实截图替换 docs/screenshots/*.png.md 和 docs/profiler-*.htrace.md 占位**。

## 截图 / Profiler 截图说明

- `docs/screenshots/baseline.png` —— v1 列表滚动时 Profiler 时间轴长帧密集（占位）
- `docs/screenshots/optimized.png` —— v3 列表滚动时 Profiler 时间轴长帧稀疏（占位）
- `docs/profiler-baseline.htrace` —— v1 完整 60s trace 二进制（占位）
- `docs/profiler-optimized.htrace` —— v3 完整 60s trace 二进制（占位）

四个文件 M7 阶段为 Markdown 占位，M8 真机批次替换。

## 与教程章节的对应关系

| 章节 | 数据 / 文件引用 |
|---|---|
| §21.3.1 性能债诊断 | "修复点对照"表 |
| §21.3.2 修复实操 | NoteStore.ets / NoteListPage.ets / Permissions.ets |
| §21.3.3 量化验证 | "量化对比"表 + DevEco Profiler 截图 |
| §21.3.4 hiTraceMeter 实战 | entry/src/main/ets/perf/HiTraceMeter.ets + 抓取脚本 |
