// SettingsPage — 占位（[feat-7] 增量补充 UserPrefs 表单）

@Component
export struct SettingsPage {
  @Consume('navPathStack') navPathStack: NavPathStack

  build() {
    NavDestination() {
      Column() {
        Text($r('app.string.title_settings'))
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .margin({ top: 24 })
        Text('（[feat-7] 提交后填充 UserPrefs 表单）')
          .fontSize(14)
          .fontColor($r('app.color.secondary_text'))
          .margin({ top: 12 })
      }
      .width('100%')
      .height('100%')
      .padding(16)
      .backgroundColor($r('app.color.page_background'))
    }
    .title($r('app.string.title_settings'))
  }
}
