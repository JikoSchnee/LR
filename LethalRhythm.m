try 
     LR
catch ME
    % 如果发生错误，停止音频
    if exist('playerAudio', 'var')
        stop(playerAudio);
    end
    rethrow(ME);
end
function LR
    % 初始设置窗口
    prompt = {'请输入地图大小:',
                '请输入障碍物的数量:',
                '请输入怪物1的数量:',
                '请输入方向怪物的数量:',
                '是否添加电磁炮(>0为true):',
                '硬核模式(>0为true):',
                '请输入BPM:'};
    dlgtitle = 'Lethal Rhythm';
    dims = [1 35];
    definput = {'15',
                '8',
                '3',
                '3',
                '1',
                '0',
                '60'};
    answer = inputdlg(prompt, dlgtitle, dims, definput);

    % 将输入转换为数值
    mapSize = str2double(answer{1});
    numEnemy1 = str2double(answer{2});
    numEnemy2 = str2double(answer{3});
    numEnemy3 = str2double(answer{4});
    if str2double(answer{5}) > 0
        numEnemy4 = 1;
    else
        numEnemy4 = 0;
    end
    if str2double(answer{6}) > 0
        rhythmMode = true;
    else
        rhythmMode = false;
    end
    BPM = str2double(answer{7});

    % 计算节拍周期
    beatPeriod = 60 / BPM;

    % 总怪物数量
    enemiesNumber = numEnemy1 + numEnemy2 + numEnemy3 + 2*numEnemy4;

    % Keyboard settings
    keyboard = ['uparrow', 'downarrow', 'leftarrow', 'rightarrow']; % 被视为行动的按键
    setting = []; % 被视为修改设置的按键

    % Map
    axis equal % 设置坐标轴为对称
    axis(0.5 + [0, mapSize, 0, mapSize]) % 加0.5是为了之后的墙壁碰撞检测的方便
    set(gca, 'xtick', 0:1:mapSize, 'ytick', 0:1:mapSize, 'xcolor', 'r', 'ycolor', 'r')
    set(gca, 'color', 'w') % 设置背景颜色为白色
    grid on
    hold on

    % 计分板
    score = 0;
    scoreText = text(mapSize + 2, mapSize - 1, ['Score: ', num2str(score)], 'FontSize', 12);

    % 节拍器
    beatColor = 'k'; % 初始颜色为黑色
    beatText = text(mapSize + 2, mapSize / 2, 'Beat', 'FontSize', 12, 'Color', beatColor);
    isBeatBlack = true;
    playerMoved = false; % 每个节拍周期内记录玩家是否已经移动
    firstMoved = false;

    player = [round(mapSize/2), round(mapSize/2)]; % 人物初始位置

    % 初始化怪物
    enemiesLocation =   [randi(mapSize, numEnemy1, 2);    
                        randi(mapSize, numEnemy2, 2);   
                        randi(mapSize, numEnemy3,2); 
                        ones(numEnemy4,2);              
                        mapSize*ones(numEnemy4,2)];

    enemiesOriginHp =   [2*ones(numEnemy1,1);             
                        ones(numEnemy2,1);              
                        ones(numEnemy3,1); 
                        7*ones(numEnemy4,1);            
                        7*ones(numEnemy4,1)];

    enemiesHp = enemiesOriginHp;

    enemiesType =   [ones(numEnemy1,1);                   
                    2*ones(numEnemy2,1);            
                    3*ones(numEnemy3,1); 
                    7*ones(numEnemy4,1);                
                    8*ones(numEnemy4,1)];

    enemiesRhythm = [ones(numEnemy1,1);                 
                    2*ones(numEnemy2,1);            
                    ones(numEnemy3,1); 
                    2*ones(numEnemy4,1);                
                    2*ones(numEnemy4,1)];

    enemiesCount = [ones(numEnemy1,1);                 
                    2*ones(numEnemy2,1);            
                    ones(numEnemy3,1); 
                    0*ones(numEnemy4,1);                
                    0*ones(numEnemy4,1)];

    enemiesScore = [0*ones(numEnemy1,1);                
                    2*ones(numEnemy2,1);            
                    ones(numEnemy3,1); 
                    0*ones(numEnemy4,1);               
                    0*ones(numEnemy4,1)];

    % 大炮弹幕
    HorizontalFirePointer = line([-0.8 -0.8], ylim, 'Color', 'r', 'LineWidth', 4, 'LineStyle', '--');
    VerticalFirePointer = line([-0.8 -0.8], ylim, 'Color', 'r', 'LineWidth', 4, 'LineStyle', '--');
    HorizontalY = 0;
    VerticalX = 0;
    HorizontalFireReady = 0; % 0 not ready; 1 ready to fire; 2 fired;
    VerticalFireReady = 0;

    plotPlayer = scatter(gca, player(:,1), player(:,2), 220, 'bs', 'filled');
    plotEnemy = cell(enemiesNumber, 1);
    for i = 1:enemiesNumber
        [color, shape] = getColorAndShape(enemiesType(i), enemiesHp(i));
        plotEnemy{i} = scatter(gca, enemiesLocation(i,1), enemiesLocation(i,2), 150, 'MarkerEdgeColor', 'k', 'MarkerFaceColor', color, 'Marker', shape);
    end

    set(gcf, 'KeyPressFcn', @key) % 设置键盘回调
    set(gcf, 'CloseRequestFcn', @closeGame);

    fps = 10; % 每秒传输帧数
    game = timer('ExecutionMode', 'FixedRate', 'Period', 1/fps, 'TimerFcn', @gameFunction);
    beatTimer = timer('ExecutionMode', 'FixedRate', 'Period', beatPeriod, 'TimerFcn', @beatFunction);
    beatTimer2 = timer('ExecutionMode', 'FixedRate', 'Period', beatPeriod, 'TimerFcn', @beatFunction2, 'StartDelay', beatPeriod / 2);
    gameSetting()

    % 音频
    [y, Fs] = audioread('bgm.mp3');
    playerAudio = audioplayer(y, Fs);
    play(playerAudio); % 开始播放音频

    start(game)
    start(beatTimer)
    start(beatTimer2)
    
    %--------------------------------------------------------------------------
    % Timer
    function gameFunction(~, ~)
    end

    %--------------------------------------------------------------------------
    % Timer for beat
    firstBeat = false;
    function beatFunction(~, ~)
        if rhythmMode
            if firstMoved == true && firstBeat == true
                if playerMoved == false
                    gameJudge(true)
                end
            elseif firstMoved == true && firstBeat == false
                firstBeat = true;
            end
        end
        playerMoved = false; % 重置玩家移动标志
        isBeatBlack = ~isBeatBlack; % 反转状态
        set(beatText, 'Color', beatColor);
    end
    function beatFunction2(~, ~)
        if isBeatBlack
            beatColor = 'r'; % 切换为红色
        else
            beatColor = 'k'; % 切换为黑色
        end
    end
    %--------------------------------------------------------------------------
    % Events of each round
    function key(~, event)
        Operation = event.Key;
        if rhythmMode == true && playerMoved == true
            gameJudge(true);
        end
        if ismember(Operation, keyboard) % 具有有效行动输入
            firstMoved = true;
            if strcmp(beatColor, 'r') && ~playerMoved % 只有在节拍器为红色且玩家未移动时才允许移动
                fireAim
                playerAction(event.Key)
                enemyAction
                playerMoved = true; % 设置玩家移动标志
                % 在地图上更新位置
                set(plotPlayer, 'XData', player(1), 'YData', player(2))
                for i = 1:enemiesNumber
                    set(plotEnemy{i}, 'XData', enemiesLocation(i,1), 'YData', enemiesLocation(i,2))
                end
            elseif strcmp(beatColor, 'k') && ~playerMoved
                fireAim
                playerAction(event.Key)
                enemyAction
                playerMoved = true; % 设置玩家移动标志
                % 在地图上更新位置
                set(plotPlayer, 'XData', player(1), 'YData', player(2))
                for i = 1:enemiesNumber
                    set(plotEnemy{i}, 'XData', enemiesLocation(i,1), 'YData', enemiesLocation(i,2))
                end
            else 
                if rhythmMode
                    gameJudge(true); % 游戏结束
                end
            end
        end
    end

    %--------------------------------------------------------------------------
    % 玩家行动
    function playerAction(key)
        switch key
            case 'rightarrow'
                if player(1) < mapSize
                    nextStep = [player(1)+1, player(2)];
                    player = handleMovement(player, nextStep);
                end
            case 'leftarrow'
                if player(1) > 1
                    nextStep = [player(1)-1, player(2)];
                    player = handleMovement(player, nextStep);
                end
            case 'uparrow'
                if player(2) < mapSize
                    nextStep = [player(1), player(2)+1];
                    player = handleMovement(player, nextStep);
                end
            case 'downarrow'
                if player(2) > 1
                    nextStep = [player(1), player(2)-1];
                    player = handleMovement(player, nextStep);
                end
        end
    end

    %--------------------------------------------------------------------------
    % 处理玩家移动和攻击逻辑
    function player = handleMovement(player, nextStep)
        if ismember(nextStep, enemiesLocation, 'rows')
            idx = find(enemiesLocation(:,1) == nextStep(1) & enemiesLocation(:,2) == nextStep(2));
            enemiesHp(idx) = enemiesHp(idx) - 1;
            if enemiesHp(idx) == 0
                player = nextStep; % 如果敌人被击败，玩家移动到该位置
                % score = score + 1; % 更新分数
                % set(scoreText, 'String', ['Score: ', num2str(score)]);
            end
            updateEnemyColorAndShape(idx); % 更新敌人的颜色和形状
        else
            player = nextStep; % 没有敌人，直接移动
        end
    end

    %--------------------------------------------------------------------------
    % 更新敌人的颜色和形状
    function updateEnemyColorAndShape(index)
        [color, shape] = getColorAndShape(enemiesType(index), enemiesHp(index));
        set(plotEnemy{index}, 'MarkerEdgeColor', 'k', 'MarkerFaceColor', color, 'Marker', shape);
    end

    %--------------------------------------------------------------------------
    % 怪物行动
    function enemyAction
        for i = 1:enemiesNumber
            enemiesCount(i) = enemiesCount(i) - 1;
            % 行动
            if enemiesCount(i) <= 0 && enemiesHp(i) > 0
                enemyAI(i);
                enemiesCount(i) = enemiesRhythm(i);
                % 检查怪物是否移动到玩家的位置
                if isequal(enemiesLocation(i,:), player)
                    gameJudge(true); % 游戏结束
                    return;
                end
            elseif enemiesHp(i) <= 0
                enemyReborn(i);
            end
        end
    end
    function fireAim
        if VerticalFireReady == 1
            VerticalFireReady = 2;
            delete(VerticalFirePointer);
            VerticalFirePointer = line([VerticalX VerticalX], ylim, 'Color', 'r', 'LineWidth', 6, 'LineStyle', '-');
        elseif VerticalFireReady == 2
            if player(1) == VerticalX
                gameJudge(true);
            end
            for i = 1:enemiesNumber
                if enemiesLocation(i,1) == VerticalX
                    enemiesHp(i) = 0;
                    enemyReborn(i);
                end
            end
            VerticalFireReady = 0;
            delete(VerticalFirePointer);
        end
        if HorizontalFireReady == 1
            HorizontalFireReady = 2;
            delete(HorizontalFirePointer);
            HorizontalFirePointer = line(xlim, [HorizontalY HorizontalY], 'Color', 'r', 'LineWidth', 6, 'LineStyle', '-');
        elseif HorizontalFireReady == 2
            if player(2) == HorizontalY
                gameJudge(true);
            end
            for i = 1:enemiesNumber
                if enemiesLocation(i,2) == HorizontalY
                    enemiesHp(i) = 0;
                    enemyReborn(i);
                end
            end
            HorizontalFireReady = 0;
            delete(HorizontalFirePointer);
        end
    end
    %--------------------------------------------------------------------------
    % 怪物AI
    function enemyAI(index)
        random_number = rand;
        temp_location = enemiesLocation(index,:);
        delta_x = player(1) - temp_location(1);
        delta_y = player(2) - temp_location(2);
        switch enemiesType(index)
            case 1
                % 障碍物
            case 2
                if delta_x == 0
                    temp_location(2) = temp_location(2) + delta_y / abs(delta_y);
                elseif delta_y == 0
                    temp_location(1) = temp_location(1) + delta_x / abs(delta_x);
                else
                    if random_number > 0.5
                        temp_location(1) = temp_location(1) + delta_x / abs(delta_x);
                    else
                        temp_location(2) = temp_location(2) + delta_y / abs(delta_y);
                    end
                end
            case 3 % 上
                temp_location(2) = temp_location(2)+1;
                if temp_location(2)>mapSize
                    temp_location(2) = temp_location(2)-mapSize;
                end
                % random_sequence = randperm(4);
                % temp = random_sequence(1)+2; %3/4/5/6
                % enemiesType(index) = temp;
            case 4 % 下
                temp_location(2) = temp_location(2)-1;
                if temp_location(2)<1
                    temp_location(2) = temp_location(2)+mapSize;
                end
                % random_sequence = randperm(4);
                % temp = random_sequence(1)+2; %3/4/5/6
                % enemiesType(index) = temp;
            case 5 % 左
                temp_location(1) = temp_location(1)-1;
                if temp_location(1)<1
                    temp_location(1) = temp_location(1)+mapSize;
                end
                % random_sequence = randperm(4);
                % temp = random_sequence(1)+2; %3/4/5/6
                % enemiesType(index) = temp;
            case 6 % 右
                temp_location(1) = temp_location(1)+1;
                if temp_location(1)>mapSize
                    temp_location(1) = temp_location(1)-mapSize;
                end
                % random_sequence = randperm(4);
                % temp = random_sequence(1)+2; %3/4/5/6
                % enemiesType(index) = temp;
            case 7 % 上下大炮
                loc = enemiesLocation(index, :);
                x = loc(1);
                if delta_x ~= 0
                    temp_location(1) = temp_location(1) + delta_x / abs(delta_x);
                else
                    if VerticalFireReady==0
                        VerticalFireReady=1;
                        VerticalFirePointer=line([x x], ylim, 'Color', 'm', 'LineWidth', 2, 'LineStyle', '--');
                        VerticalX = x;
                    end
                end
            case 8 % 左右大炮
                loc = enemiesLocation(index, :);
                y = loc(2);
                if delta_y ~= 0
                    temp_location(2) = temp_location(2) + delta_y / abs(delta_y);
                else
                    if HorizontalFireReady==0
                        HorizontalFireReady=1;
                        HorizontalFirePointer=line(xlim, [y y], 'Color', 'm', 'LineWidth', 2, 'LineStyle', '--');
                        HorizontalY = y;
                    end
                end
        end
        if ismember(temp_location, enemiesLocation, 'rows')
            idx = find(enemiesLocation(:,1) == temp_location(1) & enemiesLocation(:,2) == temp_location(2));
            if idx ~= index
                enemiesHp(idx) = enemiesHp(idx) - 1;
                if enemiesHp(idx) == 0
                    enemiesLocation(index,:) = temp_location; % 如果敌人被击败，移动到该位置
                    enemyReborn(idx);
                    % score = score + 1; % 更新分数
                    % set(scoreText, 'String', ['Score: ', num2str(score)]);
                end
                updateEnemyColorAndShape(idx); % 更新敌人的颜色和形状
            end
        else
            enemiesLocation(index,:) = temp_location; % 没有敌人，直接移动
            updateEnemyColorAndShape(index); % 更新敌人的颜色和形状
        end
        
    end

    %--------------------------------------------------------------------------
    % 敌人重生
    function enemyReborn(index)
        if isnumeric(score)
            score = score + enemiesScore(index);
        else
            warning('Score is not numeric. Check for issues.');
        end
        score = score + enemiesScore(index);
        set(scoreText, 'String', ['Score: ', num2str(score)]);
        switch enemiesType(index)
            case 1
                % 障碍物
                enemiesLocation(index,:) = [randi(mapSize), randi(mapSize)];
            case 2
                % 二步普通怪
                tempx = randi(1);
                tempy = randi(1);
                if tempx > 0.5
                    tempx = mapSize;
                else
                    tempx = 1;
                end
                if tempy > 0.5
                    tempy = mapSize;
                else
                    tempy = 1;
                end
                enemiesLocation(index,:) = [tempx, tempy];
            case 3
                % 随机朝向怪↑
                enemiesLocation(index,:) = [randi(mapSize-2)+1, 2];
                random_sequence = randperm(4);
                temp = random_sequence(1)+2; %3/4/5/6
                enemiesType(index) = temp;
            case 4
                % 随机朝向怪↓
                enemiesLocation(index,:) = [randi(mapSize-2)+1, mapSize-1];
                random_sequence = randperm(4);
                temp = random_sequence(1)+2; %3/4/5/6
                enemiesType(index) = temp;
            case 5
                % 随机朝向怪←
                enemiesLocation(index,:) = [mapSize-1, randi(mapSize-2)+1];
                random_sequence = randperm(4);
                temp = random_sequence(1)+2; %3/4/5/6
                enemiesType(index) = temp;
            case 6
                % 随机朝向怪→
                enemiesLocation(index,:) = [2, randi(mapSize-2)+1];
                random_sequence = randperm(4);
                temp = random_sequence(1)+2; %3/4/5/6
                enemiesType(index) = temp;
            case 7
                % 边界大炮上下
                tempx = enemiesLocation(index,1);
                tempy = randi(1);
                if tempy > 0.5
                    tempy = mapSize;
                else
                    tempy = 1;
                end
                enemiesLocation(index,:) = [tempx, tempy];
            case 8
                % 边界大炮左右
                tempx = randi(1);
                tempy = enemiesLocation(index,2);
                if tempx > 0.5
                    tempx = mapSize;
                else
                    tempx = 1;
                end
                enemiesLocation(index,:) = [tempx, tempy];
        end
        enemiesHp(index) = enemiesOriginHp(index);
        updateEnemyColorAndShape(index); % 重生时更新颜色和形状
    end

    %--------------------------------------------------------------------------
    % 判定游戏是否结束
    function gameJudge(isGameOver)
        if isGameOver
            stop(game);
            stop(beatTimer);
            stop(beatTimer2);
            stop(playerAudio); % 暂停音频
            % 弹出得分面板
            choice = questdlg(['Game Over! Your score is: ', num2str(score), '. Do you want to restart?'], ...
                'Game Over', ...
                'Yes', 'No', 'Yes');
            switch choice
                case 'Yes'
                    close(gcf); % 关闭当前窗口
                    LR(); % 重新开始游戏
                case 'No'
                    close(gcf); % 关闭当前窗口
            end
        end
    end
    
    %--------------------------------------------------------------------------
    % 游戏设置
    function gameSetting
    end
    function closeGame(~, ~)
    try
        stop(game);
        stop(beatTimer);
        stop(beatTimer2);
        stop(playerAudio); % 停止音频
    catch
    end
    delete(gcf); % 删除窗口
end
    %--------------------------------------------------------------------------
    % 获取颜色和形状
    function [color, shape] = getColorAndShape(type, hp)
        % 定义彩虹的七色
        rainbowColors = [
            1, 0, 0;       % 红色
            1, 0.64, 0;     % 橙色
            1, 1, 0;       % 黄色
            0, 1, 0;       % 绿色
            0, 0.5, 1;       % 蓝色
            0, 0, 1; % 靛蓝色
            0.56, 0, 1     % 紫色
        ];
    
        % 定义形状代码
        shapes = {'s', 'o', '^', 'v', '<', '>', 'p', 'p', '.', 'd', 's'};
    
        % 确保类型在范围内
        if type < 1 || type > 8
            error('Type must be an integer between 1 and 8.');
        end
    
        % 获取对应的颜色和形状
        if hp <= 0
            color = rainbowColors(min(1, size(rainbowColors, 1)), :);
        else
            color = rainbowColors(min(hp, size(rainbowColors, 1)), :);
        end
        shape = shapes{type};
    end
end
