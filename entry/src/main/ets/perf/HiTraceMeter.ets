// hiTraceMeter 自定义打点占位（baseline 阶段同样需要打点框架，否则无法对照 optimized）
// v3-perf-baseline 与 v3-perf-optimized 共用此打点框架；区别在于 NoteListPage / NoteStore 的实现是否含教学型性能债。
import { hiTraceMeter } from '@kit.PerformanceAnalysisKit'

let nextId = 1

export function startTrace(name: string): number {
  const id = nextId++
  hiTraceMeter.startTrace(name, id)
  return id
}

export function finishTrace(name: string, id: number): void {
  hiTraceMeter.finishTrace(name, id)
}

export function countTrace(name: string, count: number): void {
  hiTraceMeter.traceByValue(name, count)
}
