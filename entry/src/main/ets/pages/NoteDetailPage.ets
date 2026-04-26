// NoteDetailPage — 占位（[feat-1] 仅渲染列表，详情由 [feat-2] 增量补充）

@Component
export struct NoteDetailPage {
  @Consume('navPathStack') navPathStack: NavPathStack

  build() {
    NavDestination() {
      Column() {
        Text($r('app.string.title_note_detail'))
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .margin({ top: 24 })
        Text('（[feat-2] 提交后填充编辑表单）')
          .fontSize(14)
          .fontColor($r('app.color.secondary_text'))
          .margin({ top: 12 })
      }
      .width('100%')
      .height('100%')
      .padding(16)
      .backgroundColor($r('app.color.page_background'))
    }
    .title($r('app.string.title_note_detail'))
  }
}
