# 脊髓区域WFA和PV分析项目

## 项目概述

本项目是一个用于分析脊髓区域WFA（Wisteria Floribunda Agglutinin，紫藤凝集素）和PV（Parvalbumin，小白蛋白）标记的自动化图像分析系统。该系统使用机器学习方法对荧光显微镜图像进行细胞检测、分类和共定位分析。

## 项目结构

```
matlab/
├── P1_prepareMouseFolder.m          # 数据预处理：文件夹准备和图像翻转
├── P2_prepareMasks_Otsu.m           # 掩码生成：使用Otsu方法自动生成脑切片掩码
├── P3_prepareXmlFiles.m             # 元数据创建：生成XML信息文件
├── P5_batchEditSliceMask.m          # 掩码编辑：批量编辑切片掩码
├── rf01_generateTrainingImages.m    # 训练数据生成：提取训练图像
├── rf02_trainRandomForestModel.m    # 模型训练：训练随机森林分类器
├── A1_batchQuantifyDots.m           # 点状荧光分析：细胞检测和量化
├── A2_batchQuantifyDiffuse.m        # 弥散荧光分析：区域荧光强度分析
├── A3_colocalizationAnalysis.m      # 共定位分析：WFA和PV共定位分析
├── process_rawData.py               # Python数据预处理脚本
└── utilities/                       # 工具函数库
    ├── allSlicesFromXml.m           # XML文件解析
    ├── binarizeWFA.m                # WFA通道二值化
    ├── binarizePV.m                 # PV通道二值化
    ├── cellClassifier.m             # 细胞分类器
    ├── cellLabeler.m                # 细胞标注工具
    ├── extractSubImage.m            # 子图像提取
    ├── listfiles.m                  # 文件列表获取
    ├── simpleReconstruct.m          # 简单重建
    └── Slice.m                      # 切片类定义
```

## 运行流程

### 第一阶段：数据预处理（P系列脚本）

#### 1. P1_prepareMouseFolder.m
**功能**：准备小鼠数据文件夹结构
- 创建必要的目录结构（hiRes、thumbnails、masks等）
- 处理图像翻转（根据解剖学方向）
- 分离多通道图像
- 生成缩略图

**运行顺序**：首先运行
**输入**：原始TIFF图像文件
**输出**：组织化的文件夹结构和分离的通道图像

#### 2. P2_prepareMasks_Otsu.m
**功能**：自动生成脑切片掩码
- 使用Otsu阈值分割方法
- 自动检测脑组织边界
- 生成二值掩码文件

**运行顺序**：P1之后
**输入**：缩略图文件
**输出**：掩码文件（PNG格式）

#### 3. P3_prepareXmlFiles.m
**功能**：创建元数据文件
- 生成miceData.xlsx（小鼠信息表）
- 创建-info.xml文件（切片元数据）

**运行顺序**：P2之后
**输入**：文件夹结构和图像信息
**输出**：XML元数据文件

#### 4. P5_batchEditSliceMask.m
**功能**：批量编辑掩码
- 预处理掩码（去噪、填充孔洞）
- 提供掩码编辑界面

**运行顺序**：P3之后（可选）
**输入**：掩码文件
**输出**：优化后的掩码文件

### 第二阶段：模型训练（RF系列脚本）

#### 5. rf01_generateTrainingImages.m
**功能**：生成训练数据
- 从数据集中随机提取细胞图像
- 支持多通道处理（WFA、PV）
- 生成标注界面供人工标注

**运行顺序**：P5之后
**输入**：高分辨率图像和细胞计数文件
**输出**：训练图像和标注文件

#### 6. rf02_trainRandomForestModel.m
**功能**：训练随机森林分类器
- 为每个通道训练独立的分类器
- 使用标注的训练数据
- 保存训练好的模型

**运行顺序**：rf01之后
**输入**：训练图像和标注
**输出**：训练好的模型文件（.mat）

### 第三阶段：数据分析（A系列脚本）

#### 7. A1_batchQuantifyDots.m
**功能**：点状荧光分析
- 检测和量化单个细胞
- 计算细胞位置、大小、荧光强度
- 生成细胞计数数据

**运行顺序**：rf02之后
**输入**：高分辨率图像和训练好的模型
**输出**：细胞量化数据（CSV文件）

#### 8. A2_batchQuantifyDiffuse.m
**功能**：弥散荧光分析
- 分析区域荧光强度
- 计算平均荧光密度
- 量化背景荧光

**运行顺序**：A1之后
**输入**：高分辨率图像
**输出**：区域荧光数据（CSV文件）

#### 9. A3_colocalizationAnalysis.m
**功能**：共定位分析
- 分析WFA和PV的共定位情况
- 计算共定位率
- 分类细胞类型

**运行顺序**：A1和A2之后
**输入**：细胞量化数据
**输出**：共定位分析结果（CSV文件）

## 统计量和计算公式

### A1_batchQuantifyDots.m 统计量

**输出CSV文件包含以下统计量：**

1. **细胞位置** (x, y)
   - 计算公式：细胞质心坐标
   - 物理意义：细胞在图像中的空间位置

2. **细胞面积** (areaPx)
   - 计算公式：`areaPx = sum(mask(:))`
   - 物理意义：细胞在像素单位下的面积

3. **平均荧光强度** (fluoMean)
   - 计算公式：`fluoMean = mean(image(mask))`
   - 物理意义：细胞区域的平均荧光信号强度

4. **中位数荧光强度** (fluoMedian)
   - 计算公式：`fluoMedian = median(image(mask))`
   - 物理意义：细胞区域荧光强度的中位数，对异常值更鲁棒

5. **最大荧光强度** (fluoMax)
   - 计算公式：`fluoMax = max(image(mask))`
   - 物理意义：细胞区域的最大荧光信号

6. **荧光强度标准差** (fluoStd)
   - 计算公式：`fluoStd = std(image(mask))`
   - 物理意义：细胞内荧光信号的变异性

### A2_batchQuantifyDiffuse.m 统计量

**输出CSV文件包含以下统计量：**

1. **区域面积** (areaPx, areaMm2)
   - 计算公式：`areaPx = sum(mask(:))`，`areaMm2 = areaPx * (pixelSize/1000)²`
   - 物理意义：分析区域的面积（像素和平方毫米）

2. **总荧光强度** (diffFluo)
   - 计算公式：`diffFluo = sum(image(mask))`
   - 物理意义：区域内所有像素的荧光强度总和

3. **平均像素强度** (avgPxIntensity)
   - 计算公式：`avgPxIntensity = diffFluo / areaPx`
   - 物理意义：单位面积的平均荧光强度

4. **切片平均荧光** (avgFluo)
   - 计算公式：`avgFluo = mean(sliceFluo)`
   - 物理意义：整个切片的平均荧光强度

### A3_colocalizationAnalysis.m 统计量

**输出CSV文件包含以下统计量：**

1. **共定位细胞数量** (num_colocalized)
   - 计算公式：`num_colocalized = sum(distance < minDist)`
   - 物理意义：距离小于阈值的WFA和PV细胞对数量

2. **共定位率** (colocalization_rate)
   - 计算公式：`colocalization_rate = num_colocalized / total_cells * 100`
   - 物理意义：共定位细胞占总细胞数的百分比

3. **细胞分类统计**
   - WFA+PV+：共定位细胞
   - WFA+PV-：仅WFA阳性细胞
   - WFA-PV+：仅PV阳性细胞

4. **距离分析** (minDistances)
   - 计算公式：`minDistances = min(pdist2(coord_pv, coord_wfa))`
   - 物理意义：最近邻细胞间的欧几里得距离

## 配置说明

### 路径配置
所有脚本都需要配置以下路径：
- `base_path`：项目根目录
- `mouse`：小鼠ID
- `defaultFolder`：数据集目录
- `outputFolder`：结果输出目录

### 参数配置
- `channels`：要分析的通道（如["wfa", "pv"]）
- `minDist`：共定位判断距离阈值（像素）
- `cellSize`：细胞提取尺寸（像素）
- `pixelSize`：像素尺寸（微米）

## 依赖项

- MATLAB R2019b或更高版本
- Image Processing Toolbox
- Statistics and Machine Learning Toolbox
- Python 3.x（用于process_rawData.py）

## 注意事项

1. 确保所有路径配置正确
2. 按顺序运行脚本
3. 检查中间输出文件
4. 根据实际数据调整参数
5. 定期备份重要数据

## 技术支持

如有问题，请检查：
1. 文件路径是否正确
2. 依赖项是否安装
3. 数据格式是否符合要求
4. 参数设置是否合理
