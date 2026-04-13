# LARC Pitch Messaging

## One-line positioning

### English

LARC is a permission-first runtime for AI agents that work inside Lark.

### Japanese

LARC は、Lark の中で仕事をする AI エージェントのための、権限管理付き実行環境です。

### Chinese

LARC 是一个面向飞书内工作型 AI Agent 的、以权限管理为核心的运行时环境。

## Short pitch

### English

Most agent runtimes assume local files, code, git, and CI.

LARC starts from a different assumption: office-work agents should run inside Lark itself, with Drive, Base, IM, Approval, and Wiki treated as the operating surface.

The core idea is permission-first execution:

- what permissions are needed
- whose authority should be used
- what review or approval gate should be applied before execution

### Japanese

多くのエージェント runtime は、ローカルファイル、コード、git、CI を前提にしています。

LARC はそこを逆転させます。一般業務向けのエージェントは、Lark Drive、Base、IM、Approval、Wiki を実行面として、Lark の中で動くべきだ、という前提です。

中核にあるのは permission-first execution です。

- どの権限が必要か
- 誰の権限として動くべきか
- 実行前にどのゲートを通すべきか

を先に明示してから動かします。

### Chinese

大多数 Agent runtime 默认面向本地文件、代码、git 和 CI。

LARC 的前提不同：面向办公工作的 Agent 应该直接在飞书内部运行，把 Drive、Base、IM、Approval、Wiki 当作运行表面。

它的核心是 permission-first execution：

- 需要哪些权限
- 应该使用谁的权限主体
- 执行前需要经过哪一种预览或审批 gate

## Very short pitch

### English

LARC is the runtime layer for office-work agents inside Lark.

### Japanese

LARC は、Lark で働く AI エージェントの runtime layer です。

### Chinese

LARC 是飞书内办公 Agent 的 runtime layer。

## Honest current-state note

### English

Today, LARC is a working runtime surface and governance layer. The fully autonomous agent loop is the next phase.

### Japanese

現時点の LARC は、動作する runtime surface と governance layer です。完全な自律ループは次フェーズです。

### Chinese

当前的 LARC 已经是可运行的 runtime surface 与 governance layer，但完整的自治循环仍是下一阶段。
