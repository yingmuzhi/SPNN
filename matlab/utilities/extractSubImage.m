function subImg = extractSubImage(sourceImg, XY, outSize, channel)
% subImg = extractSubImage(sourceImg, XY, outSize, channel)
if nargin < 4
    channel = 1;
end

[width, height] = size(sourceImg, [2, 1]);

% Check that the requested sumIng size is even
if mod(outSize,2) ~= 0
    outSize = outSize+1;
    warning('outSize must be an even number, corrected to %upx', outSize)
end

% Borders of the output image
xPoints = [XY(1)-(outSize/2)+1 XY(1)+(outSize/2)];
yPoints = [XY(2)-(outSize/2)+1 XY(2)+(outSize/2)];

% Resolve possible border effects for the X axis
if xPoints(1) < 1
    xPoints = [1 outSize];
elseif xPoints(2) > width
    xPoints = [width-outSize+1 width];
end
% Resolve possible border effects for the Y axis
if yPoints(1) < 1
    yPoints = [1 outSize];
elseif yPoints(2) > height
    yPoints = [height-outSize+1 height];
end

subImg = sourceImg(yPoints(1):yPoints(2) , xPoints(1):xPoints(2), channel);
end