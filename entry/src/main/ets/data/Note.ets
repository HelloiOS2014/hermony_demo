// 数据 schema：v1 起即固定，v2+ 兼容（v2 起会在 RDB 表上加分布式属性）
// 与 §21.1 教程 Note 类型一一对应

export interface Note {
  id: string         // UUID v4
  title: string      // 笔记标题
  content: string    // 正文（v1 文本 / v2+ 简单 markdown）
  createdAt: number  // 创建时间戳 ms
  updatedAt: number  // 修改时间戳 ms
  tags: string[]     // 标签数组
}

export interface UserPrefs {
  themeMode: 'light' | 'dark' | 'system'
  defaultTags: string[]
  syncEnabled: boolean  // v1 默认 false；v2+ 才真正接 distributedDataObject
}

// 简易 UUID v4 生成（生产可换 @ohos.util uuid）
export function genNoteId(): string {
  const seg = (n: number): string => {
    let s = ''
    for (let i = 0; i < n; i++) {
      s += Math.floor(Math.random() * 16).toString(16)
    }
    return s
  }
  return seg(8) + '-' + seg(4) + '-4' + seg(3) + '-' + seg(4) + '-' + seg(12)
}

// 5 条预置笔记：首次启动 + RDB 表为空时插入，便于 §21.1 教程"开箱即用"演示
export function seedNotes(): Note[] {
  const now = Date.now()
  return [
    {
      id: genNoteId(),
      title: '欢迎使用 Hermony 笔记',
      content: '这是 §21.1 单端笔记 demo，对照 §21.3 性能优化章节阅读。',
      createdAt: now - 5 * 86400000,
      updatedAt: now - 5 * 86400000,
      tags: ['入门']
    },
    {
      id: genNoteId(),
      title: '会议记录 · 2026-04-20',
      content: '议题：M7 实战章节排期。结论：5 实战累积演进 + 双仓 7 commit pair。',
      createdAt: now - 4 * 86400000,
      updatedAt: now - 4 * 86400000,
      tags: ['工作', '会议']
    },
    {
      id: genNoteId(),
      title: 'ArkUI 学习清单',
      content: '1. NavPathStack\n2. LazyForEach + cachedCount\n3. V2 @ObservedV2/@Trace\n4. 资源限定词',
      createdAt: now - 3 * 86400000,
      updatedAt: now - 3 * 86400000,
      tags: ['学习', 'ArkUI']
    },
    {
      id: genNoteId(),
      title: '周末购物清单',
      content: '牛奶、面包、鸡蛋、苹果。',
      createdAt: now - 2 * 86400000,
      updatedAt: now - 2 * 86400000,
      tags: ['生活']
    },
    {
      id: genNoteId(),
      title: '读书摘抄',
      content: '"程序员修炼之道"：DRY / 正交性 / 可逆性。',
      createdAt: now - 86400000,
      updatedAt: now - 86400000,
      tags: ['读书', '摘抄']
    }
  ]
}
