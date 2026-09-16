<template>
    <div class="login-container">
        <el-card class="login-box">
            <h2>秒杀系统登录</h2>
            <el-form :model="form" :rules="rules" ref="loginForm">
                <el-form-item label="用户名" prop="username">
                    <el-input v-model="form.username" placeholder="请输入用户名"></el-input>
                </el-form-item>
                <el-form-item label="密码" prop="password">
                    <el-input v-model="form.password" type="password" placeholder="请输入密码"></el-input>
                </el-form-item>
                <el-form-item>
                    <el-button type="primary" @click="handleLogin" :loading="loading">登录</el-button>
                </el-form-item>
            </el-form>
        </el-card>
    </div>
</template>

<script>
import request from '@/utils/request'

export default {
    data() {
        return {
            loading: false,
            form: {
                username: '',
                password: ''
            },
            rules: {
                username: [{ required: true, message: '请输入用户名', trigger: 'blur' }],
                password: [{ required: true, message: '请输入密码', trigger: 'blur' }]
            }
        }
    },
    methods: {
        async handleLogin() {
            // 1. 表单验证
            const valid = await this.$refs.loginForm.validate().catch(() => false);
            if (!valid) return;

            this.loading = true;
            try {
                // 2. 调用登录接口
                // 注意：后端用的是 OAuth2PasswordRequestForm，需要传 form-data
                const params = new URLSearchParams();
                params.append('username', this.form.username);
                params.append('password', this.form.password);
                params.append('grant_type', 'password');
                // 注意：后端用的是 Oauth2PasswordRequestForm 需要传 form-data 格式
                const res = await request.post('/auth/login', params, {
                    headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
                });
                // 3. 登录成功，保存 Token 
                localStorage.setItem('token', res.access_token);
                // 提示成功
                this.$message.success('登录成功');
                // 跳转到首页
                window.location.href = '/';
            } catch (error) {
                this.$message.error(error.response?.data?.detail || '登录失败');
            } finally {
                this.loading = false;
            }
        }
    }
}
</script>

<style scoped>
.login-container {
    display: flex;
    justify-content: center;
    align-items: center;
    height: 100vh;
    background-color: #f5f5f5;
}
.login-box {
    width: 400px;
}
.login-box h2 {
    text-align: center;
    margin-bottom: 30px;
}
</style>

<!-- 
"重点解释几个地方："
    URLSearchParams ：后端用的是 OAuth2PasswordRequestForm ，需要 form-data 格式，不是 JSON。
    所以用 URLSearchParams 构造表单数据。
    
    grant_type: 'password' ：后端要求的固定字段，还记得吗？
    
    localStorage.setItem('token', ...) ：Token 存到浏览器本地，刷新页面也不会丢。
    
    this.$router.push('/') ：登录成功后跳转到首页。
-->