# 海因影视 - 安卓TV版改造计划

## 项目现状分析
- 这是一个Flutter项目，主要用于视频播放
- 包含登录界面、主界面、各种视频列表和播放界面
- 使用了Provider进行状态管理
- 有豆瓣影视推荐、继续观看等功能

## 改造目标
1. **全局支持遥控器控制**，特别是登录时的输入界面
2. **重构主界面布局**，第一行显示豆瓣影视推荐，海报加大显示
3. **继续观看**放到第二行
4. **确保软件图标**匹配TV版显示
5. **确保在电视安装后**能正常显示在应用列表中

## 详细任务计划

### [x] 任务1：添加TV平台支持和遥控器导航
- **Priority**: P0
- **Depends On**: None
- **Description**:
  - 添加TV平台检测
  - 实现遥控器导航支持
  - 为所有可交互元素添加焦点管理
- **Success Criteria**:
  - 应用能在TV设备上正常运行
  - 所有界面元素都能通过遥控器导航
  - 焦点状态清晰可见
- **Test Requirements**:
  - `programmatic` TR-1.1: 应用能在TV设备上启动并正常运行
  - `human-judgement` TR-1.2: 所有界面元素都能通过遥控器方向键和确认键操作

### [x] 任务2：修改登录界面支持遥控器输入
- **Priority**: P0
- **Depends On**: 任务1
- **Description**:
  - 为登录界面的输入框添加焦点管理
  - 实现遥控器方向键在输入框之间的导航
  - 为输入框添加TV友好的虚拟键盘
- **Success Criteria**:
  - 登录界面能通过遥控器完全操作
  - 输入框之间能通过方向键导航
  - 虚拟键盘能正常显示和使用
- **Test Requirements**:
  - `programmatic` TR-2.1: 能通过遥控器完成登录流程
  - `human-judgement` TR-2.2: 输入体验流畅，焦点切换自然

### [x] 任务3：重构主界面布局
- **Priority**: P1
- **Depends On**: 任务1
- **Description**:
  - 调整主界面布局，将豆瓣影视推荐放在第一行
  - 加大豆瓣影视推荐的海报显示尺寸
  - 将继续观看功能放到第二行
- **Success Criteria**:
  - 主界面布局符合要求，豆瓣影视推荐在第一行
  - 海报尺寸适合TV显示
  - 继续观看功能在第二行
- **Test Requirements**:
  - `human-judgement` TR-3.1: 布局美观，符合TV观看习惯
  - `human-judgement` TR-3.2: 海报尺寸合适，显示清晰

### [x] 任务4：修改应用图标和配置
- **Priority**: P1
- **Depends On**: None
- **Description**:
  - 使用logo.png修改应用图标
  - 添加TV应用标识到AndroidManifest.xml
  - 确保应用能被TV设备识别为TV应用
- **Success Criteria**:
  - 应用图标使用logo.png修改
  - 应用能在TV设备的应用列表中显示
  - 应用被正确识别为TV应用
- **Test Requirements**:
  - `programmatic` TR-4.1: 应用能在TV设备上安装并显示在应用列表
  - `human-judgement` TR-4.2: 应用图标显示正常

### [/] 任务5：测试和优化
- **Priority**: P2
- **Depends On**: 任务1-4
- **Description**:
  - 在TV设备上测试所有功能
  - 优化遥控器导航体验
  - 修复可能的布局问题
- **Success Criteria**:
  - 所有功能在TV设备上正常运行
  - 遥控器导航体验流畅
  - 布局在不同尺寸的TV屏幕上都能正常显示
- **Test Requirements**:
  - `programmatic` TR-5.1: 所有功能测试通过
  - `human-judgement` TR-5.2: 整体体验流畅，符合TV应用标准

## 技术实现要点
1. **Flutter TV支持**：使用Flutter的FocusNode和FocusManager实现遥控器导航
2. **布局调整**：使用MediaQuery和LayoutBuilder实现响应式布局，针对TV屏幕优化
3. **输入处理**：为TV设备添加虚拟键盘支持
4. **应用配置**：修改AndroidManifest.xml添加TV应用标识
5. **图标处理**：使用logo.png生成适合TV显示的应用图标

## 预期交付物
- 支持TV遥控器控制的应用
- 优化后的主界面布局
- 正确识别为TV应用的配置
- 在TV设备上正常运行的应用