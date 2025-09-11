#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
process_rawData.py
处理TIFF图像数据，支持多通道、多切片数据的读取、组合和保存
"""

import numpy as np
import tifffile
import os
from typing import List, Tuple, Optional
import argparse


class TIFFProcessor:
    """TIFF图像处理器"""
    
    def __init__(self, file_path: str):
        """
        初始化TIFF处理器
        
        Args:
            file_path: TIFF文件路径
        """
        self.file_path = file_path
        self.data = None
        self.shape = None
        self.n_channels = 0
        self.n_slices = 0
        self.height = 0
        self.width = 0
        
    def load_tiff(self) -> bool:
        """
        加载TIFF文件
        
        Returns:
            bool: 加载是否成功
        """
        try:
            print(f"正在加载文件: {self.file_path}")
            self.data = tifffile.imread(self.file_path)
            self.shape = self.data.shape
            
            # 判断数据维度
            if len(self.shape) == 2:
                # 2D图像 (height, width)
                self.height, self.width = self.shape
                self.n_channels = 1
                self.n_slices = 1
            elif len(self.shape) == 3:
                # 可能是 (channels, height, width) 或 (slices, height, width)
                if self.shape[0] <= 4:  # 通常通道数不超过4
                    self.n_channels = self.shape[0]
                    self.height, self.width = self.shape[1], self.shape[2]
                    self.n_slices = 1
                else:  # 可能是切片
                    self.n_slices = self.shape[0]
                    self.height, self.width = self.shape[1], self.shape[2]
                    self.n_channels = 1
            elif len(self.shape) == 4:
                # 4D图像 (slices, channels, height, width) 或 (channels, slices, height, width)
                if self.shape[1] <= 4:  # 第二个维度是通道
                    self.n_slices = self.shape[0]
                    self.n_channels = self.shape[1]
                    self.height, self.width = self.shape[2], self.shape[3]
                else:  # 第一个维度是通道
                    self.n_channels = self.shape[0]
                    self.n_slices = self.shape[1]
                    self.height, self.width = self.shape[2], self.shape[3]
            else:
                print(f"不支持的数据维度: {self.shape}")
                return False
                
            print(f"文件加载成功!")
            return True
            
        except Exception as e:
            print(f"加载文件失败: {e}")
            return False
    
    def display_info(self):
        """显示图像信息"""
        if self.data is None:
            print("请先加载图像数据")
            return
            
        print("\n" + "="*50)
        print("图像信息:")
        print("="*50)
        print(f"文件路径: {self.file_path}")
        print(f"数据形状: {self.shape}")
        print(f"通道数 (Channels): {self.n_channels}")
        print(f"切片数 (Slices): {self.n_slices}")
        print(f"图像尺寸: {self.height} x {self.width}")
        print(f"数据类型: {self.data.dtype}")
        print("="*50)
    
    def get_channel_data(self, channel_idx: int) -> np.ndarray:
        """
        获取指定通道的数据
        
        Args:
            channel_idx: 通道索引 (从0开始)
            
        Returns:
            np.ndarray: 通道数据
        """
        if self.data is None:
            raise ValueError("请先加载图像数据")
            
        if channel_idx >= self.n_channels:
            raise ValueError(f"通道索引超出范围 (0-{self.n_channels-1})")
        
        if len(self.shape) == 2:
            return self.data
        elif len(self.shape) == 3:
            if self.n_channels > 1:
                return self.data[channel_idx]
            else:
                return self.data
        elif len(self.shape) == 4:
            if self.shape[1] <= 4:  # (slices, channels, height, width)
                return self.data[:, channel_idx, :, :]
            else:  # (channels, slices, height, width)
                return self.data[channel_idx, :, :, :]
    
    def combine_channels(self, channel_a: int, channel_b: int, channel_c: int, 
                        output_a: int = 0, output_b: int = 1, output_c: int = 2) -> np.ndarray:
        """
        将三个通道组合成一个RGB图像
        
        Args:
            channel_a: 输入通道A索引
            channel_b: 输入通道B索引  
            channel_c: 输入通道C索引
            output_a: 通道A在输出中的位置 (0=Red, 1=Green, 2=Blue)
            output_b: 通道B在输出中的位置 (0=Red, 1=Green, 2=Blue)
            output_c: 通道C在输出中的位置 (0=Red, 1=Green, 2=Blue)
            
        Returns:
            np.ndarray: 组合后的图像数据
        """
        if self.data is None:
            raise ValueError("请先加载图像数据")
        
        # 获取各通道数据
        ch_a_data = self.get_channel_data(channel_a)
        ch_b_data = self.get_channel_data(channel_b)
        ch_c_data = self.get_channel_data(channel_c)
        
        # 确保数据在0-255范围内
        def normalize_channel(data):
            if data.dtype != np.uint8:
                data = data.astype(np.float32)
                data = (data - data.min()) / (data.max() - data.min() + 1e-8)
                data = (data * 255).astype(np.uint8)
            return data
        
        ch_a_data = normalize_channel(ch_a_data)
        ch_b_data = normalize_channel(ch_b_data)
        ch_c_data = normalize_channel(ch_c_data)
        
        # 验证输出通道位置
        output_positions = [output_a, output_b, output_c]
        if len(set(output_positions)) != 3 or not all(0 <= pos <= 2 for pos in output_positions):
            raise ValueError("输出通道位置必须是0, 1, 2且互不相同")
        
        # 创建输出通道数组
        if len(ch_a_data.shape) == 2:  # 单切片
            # 创建空的RGB图像
            combined = np.zeros((ch_a_data.shape[0], ch_a_data.shape[1], 3), dtype=np.uint8)
            # 将各通道数据放到指定位置
            combined[:, :, output_a] = ch_a_data
            combined[:, :, output_b] = ch_b_data
            combined[:, :, output_c] = ch_c_data
        else:  # 多切片
            # 创建空的RGB图像堆栈
            combined = np.zeros((ch_a_data.shape[0], ch_a_data.shape[1], ch_a_data.shape[2], 3), dtype=np.uint8)
            # 将各通道数据放到指定位置
            combined[:, :, :, output_a] = ch_a_data
            combined[:, :, :, output_b] = ch_b_data
            combined[:, :, :, output_c] = ch_c_data
        
        return combined
    
    def save_stacks(self, combined_data: np.ndarray, output_dir: str, prefix: str = "Mouse1Month8Region124", suffix: str = "_A1_1"):
        """
        将组合后的数据按切片保存为多个TIF文件
        
        Args:
            combined_data: 组合后的图像数据
            output_dir: 输出目录
            prefix: 文件名前缀 (例如: "Mouse1Month8Region124")
            suffix: 文件名后缀 (例如: "_A1_1")
        """
        if not os.path.exists(output_dir):
            os.makedirs(output_dir)
        
        if len(combined_data.shape) == 3:  # 单切片
            output_path = os.path.join(output_dir, f"{prefix}_001{suffix}.tif")
            tifffile.imwrite(output_path, combined_data)
            print(f"保存文件: {output_path}")
        else:  # 多切片
            for slice_idx in range(combined_data.shape[0]):
                slice_data = combined_data[slice_idx]
                slice_number = slice_idx + 1  # 从1开始编号
                output_path = os.path.join(output_dir, f"{prefix}_{slice_number:03d}{suffix}.tif")
                tifffile.imwrite(output_path, slice_data)
                print(f"保存文件: {output_path}")


def main():
    """主函数"""
    parser = argparse.ArgumentParser(description="处理TIFF图像数据")
    parser.add_argument("--file", "-f", 
                       default=r"E:\_scj\20250903_FCY_SegPNN\src\20250903-SYR\20250911",
                       help="输入TIFF文件路径或包含TIF文件的目录")
    parser.add_argument("--output", "-o", 
                       default=r"E:\_scj\20250903_FCY_SegPNN\src\output",
                       help="输出目录")
    parser.add_argument("--channels", "-c", nargs=3, type=int, 
                       default=[0, 1, 2],
                       help="指定三个通道索引 (例如: 0 1 2)")
    parser.add_argument("--output-channels", "-oc", nargs=3, type=int, 
                       default=[1, 2, 0],
                       help="根据 --oc-mode 解释: order 模式下为 [R,G,B] 分别使用的源通道索引 (0=A,1=B,2=C); positions 模式下为 A/B/C 各自要放到的输出位置 (0=R,1=G,2=B)")
    parser.add_argument("--oc-mode", choices=["order", "positions"], default="order",
                       help="解释 --output-channels 的方式: order=指定RGB各自来自哪个输入通道; positions=指定A/B/C各自输出到RGB的哪个位置")
    parser.add_argument("--prefix", "-p", default="Mouse1Month8",
                       help=f"生成文件名开头追加的前缀 (例如: Mouse1Month8，最终如 Mouse1Month8Region124_001...) ")
    parser.add_argument("--suffix", "-s", default="_A1_1",
                       help="输出文件后缀 (例如: _A1_1)")
    
    args = parser.parse_args()

    # 根据输入决定处理单文件或目录内全部 TIF
    target_paths = []
    if os.path.isdir(args.file):
        target_dir = args.file
        target_paths = [
            os.path.join(target_dir, name)
            for name in os.listdir(target_dir)
            if name.lower().endswith('.tif')
        ]
        target_paths.sort()
        if not target_paths:
            print(f"目录中未找到TIF文件: {target_dir}")
            return
        print(f"在目录中找到 {len(target_paths)} 个TIF文件，将逐一处理: {target_dir}")
    else:
        target_paths = [args.file]

    import re

    def derive_region_prefix(file_path: str) -> str:
        base_name = os.path.basename(file_path)
        match = re.search(r'region\s*(\d+)', base_name, flags=re.IGNORECASE)
        if match:
            return f"Region{match.group(1)}"
        return "Region"

    # 如果没有指定通道，则保持默认行为（交互式仅在首次文件上触发）
    interactive_channels_selected = False
    channel_a, channel_b, channel_c = (args.channels if args.channels is not None else (0, 1, 2))
    output_a, output_b, output_c = args.output_channels

    for tif_path in target_paths:
        print("\n" + "-" * 60)
        print(f"正在处理文件: {tif_path}")
        processor = TIFFProcessor(tif_path)

        if not processor.load_tiff():
            print(f"跳过无法加载的文件: {tif_path}")
            continue

        processor.display_info()

        if args.channels is None and not interactive_channels_selected:
            print(f"\n可用通道: 0 到 {processor.n_channels-1}")
            try:
                channel_a = int(input("请输入通道A的索引: "))
                channel_b = int(input("请输入通道B的索引: "))
                channel_c = int(input("请输入通道C的索引: "))
            except ValueError:
                print("输入无效，使用默认通道 0, 1, 2")
                channel_a, channel_b, channel_c = 0, 1, 2
            interactive_channels_selected = True

        max_channel = processor.n_channels - 1
        if not all(0 <= ch <= max_channel for ch in [channel_a, channel_b, channel_c]):
            print(f"通道索引超出范围，可用通道: 0-{max_channel}，跳过该文件")
            continue

        print(f"\n使用输入通道: A={channel_a}, B={channel_b}, C={channel_c}")
        if args.oc_mode == "positions":
            print(
                f"输出通道位置 (positions): A->{output_a}({'Red' if output_a==0 else 'Green' if output_a==1 else 'Blue'}), "
                f"B->{output_b}({'Red' if output_b==0 else 'Green' if output_b==1 else 'Blue'}), "
                f"C->{output_c}({'Red' if output_c==0 else 'Green' if output_c==1 else 'Blue'})"
            )
        else:
            print(
                f"输出顺序 (order, [R,G,B] 使用源通道): R<-{output_a} (A=0,B=1,C=2), G<-{output_b}, B<-{output_c}"
            )

        try:
            print("正在组合通道...")
            if args.oc_mode == "positions":
                # 保持原有语义：A/B/C 分别放到指定输出位置
                combined_data = processor.combine_channels(
                    channel_a, channel_b, channel_c, output_a, output_b, output_c
                )
            else:
                # 新的直观语义：output_channels 表示 [R,G,B] 各自来自哪个源通道 (0=A,1=B,2=C)
                sources = [channel_a, channel_b, channel_c]
                red_source = sources[output_a]
                green_source = sources[output_b]
                blue_source = sources[output_c]
                combined_data = processor.combine_channels(
                    red_source, green_source, blue_source, 0, 1, 2
                )
            print("通道组合完成!")

            # 根据文件名派生前缀，例如 region1_xxx.tif -> Region1
            derived_prefix = derive_region_prefix(tif_path)
            # 在派生前缀前加上 --prefix 的前缀（不自动添加分隔符）
            if args.prefix:
                combined_prefix = f"{args.prefix}{derived_prefix}"
            else:
                combined_prefix = derived_prefix
            print(f"派生输出前缀: {derived_prefix} -> 实际使用: {combined_prefix}")

            print(f"正在保存到目录: {args.output}")
            processor.save_stacks(combined_data, args.output, combined_prefix, args.suffix)
            print("保存完成!")

        except Exception as e:
            print(f"处理过程中出现错误 (文件: {tif_path}): {e}")


if __name__ == "__main__":
    main()
