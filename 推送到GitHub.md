# 推送到 GitHub 步骤

按顺序执行。第一次推完以后，以后只需要 `git add . && git commit -m "xxx" && git push`。

## 0. 一次性准备（只做一次）

### 0.1 安装 Git for Windows
下载：https://git-scm.com/download/win
安装时一路默认即可。装完**重启 PowerShell**。

### 0.2 配置身份（替换成你自己的 GitHub 用户名和邮箱）
```powershell
git config --global user.name  "你的GitHub用户名"
git config --global user.email "你的GitHub注册邮箱"
```

### 0.3 在 GitHub 网页上建一个空仓库
1. 打开 https://github.com/new
2. Repository name 填：`seizure-detection-embedded`（或你喜欢的名字）
3. 描述：`Online seizure detection: MATLAB training → MATLAB online replay → STM32 C deployment`
4. **选 Private**（强烈建议——这个项目含医疗相关算法和模型参数，先私有）
5. **不要**勾 "Add a README" / "Add .gitignore" / "Choose license"（保持空仓库）
6. 点 Create repository

建好后 GitHub 会给你一个地址，长这样：
`https://github.com/你的用户名/seizure-detection-embedded.git`
复制下来。

## 1. 初始化本地仓库

在 PowerShell 里：
```powershell
cd "C:\Users\admin\Desktop\在线算法\项目整理"
git init
git branch -M main
git add .
git status    # 检查一下要提交的文件，确认没有患者数据/大 mat 文件
```

**关键检查**：`git status` 输出里
- 不应该出现 `*.mat`（除了 `04_模型参数/` 下 norm_params 和 fcm 的小文件）
- 不应该出现 `__pycache__`、`*.joblib`
- 不应该出现 `acc_data*.txt` 这类回放数据

如果看到不该推的文件，先编辑 `.gitignore` 再 `git add .`。

## 2. 首次提交并推送

```powershell
git commit -m "Initial commit: offline training + MATLAB online replay + STM32 C deployment"

# 把下面这行的 URL 换成你在 GitHub 上建仓库后拿到的地址
git remote add origin https://github.com/你的用户名/seizure-detection-embedded.git

git push -u origin main
```

第一次 push 会弹出浏览器让你登录 GitHub，按提示授权即可。

## 3. 以后日常更新

```powershell
cd "C:\Users\admin\Desktop\在线算法\项目整理"
git add .
git commit -m "描述你改了什么"
git push
```

## 4. 项目链接

推完以后，你的项目主页就是：
`https://github.com/你的用户名/seizure-detection-embedded`

可以直接分享给他人。如果想让所有人都能看到代码，把仓库改成 Public 即可
（GitHub 仓库页面 → Settings → General → Danger Zone → Change visibility）。

## 常见问题

**Q: push 时报 "Authentication failed"**
A: 用浏览器登录一下 GitHub，再跑一次 push；或者装 GitHub CLI (`gh auth login`)。

**Q: 报错 "remote origin already exists"**
A: 之前加过 remote，先 `git remote remove origin` 再加一次。

**Q: 想撤销 .gitignore 漏掉的大文件**
A: `git rm --cached 文件名`，再 commit。
