// HiTraceMeter — §21.3 自定义打点封装
//
// 关键路径打点 + 全局自增 traceId，配合 SystemTrace / DevEco Profiler 抓 60s
// trace 后在时间轴上看 startTrace/finishTrace 的耗时分布。
//
// §21.3 教程在 NoteListPage 关键路径打点：
//   - noteList.build      整列表 build() 入口（v3-optimized 后只在首屏 / reload 触发）
//   - noteList.itemBuild  单 item NoteCard build()（@Trace 字段级仅在变化项触发）
//   - noteList.scrollFrame 滚动每帧（onScrollFrameBegin 入口）
//
// 使用：
//   const id = startTrace('noteList.itemBuild')
//   ...
//   finishTrace('noteList.itemBuild', id)
//
// 模拟器抓数据脚本见 docs/perf-summary.md。

import { hiTraceMeter } from '@kit.PerformanceAnalysisKit'

// 全局自增 id：保证 nested startTrace / finishTrace 能正确配对，
// 即使同名 trace 并发也不会错串。
let nextId = 1

/**
 * 开始一段 trace，返回 traceId（finishTrace 必须传同名 + 同 id）。
 */
export function startTrace(name: string): number {
  const id = nextId++
  hiTraceMeter.startTrace(name, id)
  return id
}

/**
 * 结束一段 trace，name 必须与 startTrace 完全一致；id 来自 startTrace 返回值。
 */
export function finishTrace(name: string, id: number): void {
  hiTraceMeter.finishTrace(name, id)
}

/**
 * 计数型打点：用于"build() 调用次数"等累加值，每次 + 1 累计到 trace 时间轴。
 * §21.3 用于统计 build() 调用次数对比（v3 baseline 6420 / 60s vs optimized 320 / 60s）。
 */
export function countTrace(name: string, count: number): void {
  hiTraceMeter.traceByValue(name, count)
}
