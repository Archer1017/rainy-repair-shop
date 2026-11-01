# 雨夜修理铺

在雨夜修复旧物并进入物品回忆的 Godot 3D 叙事原型。

本仓库从历史开发代码中恢复脚本、场景和着色器，重新生成缺失的程序化音效，并补齐项目配置和公开字体。属于可继续开发的原型快照。

## 运行

使用 Godot 4.7.2 或兼容版本导入 `project.godot`，按 F6 或 F5 运行主场景。命令行中的 `godot` 指自己安装的 Godot 可执行文件。

## 验证

Godot 4.7.2 无界面运行通过；回忆流程 200 项、修理到交付的完整流程 245 项、隔离存档回归 73 项检查通过。启动退出时仍有少量对象释放告警；图形和性能尚未验收。

```sh
godot --headless --path . --script tests/story_flow.gd
godot --headless --path . --script tests/playthrough.gd -- --fresh
godot --headless --path . --script tests/persistence.gd -- --fresh
```

## 资源

- `tools/generate_audio.py` 可用 Python 3 重新生成音效。
- 字体为 Noto Sans SC，采用 SIL Open Font License 1.1；许可见 `assets/fonts/OFL.txt`。

## 当前限制

- 属于恢复后的原型快照，尚未完成图形显示、性能和完整视觉回归。
- 恢复时补齐了项目配置和几何辅助状态，不保证与历史最终版本完全一致。

## 公开版说明

不包含原聊天、私人存档、日志、个人联系方式或旧 Git 历史。第三方资源遵循其各自许可；本次整理未另行授予整体项目开源许可。
