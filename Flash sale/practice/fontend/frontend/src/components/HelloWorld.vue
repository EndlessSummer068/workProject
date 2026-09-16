<template>
  <div class="hello">
    <h1>{{ message }}</h1>
    <input type="text" v-model="message" placeholder="请输入"></input>
    <br><br>
    <button @click="handleClick">点我弹窗</button>
  </div>
</template>

<script>
export default {
  name: 'HelloWorld',
  data() {
    return {
      message: "Hello Vue!"
    }
  },
  methods: {
    handleClick() {
      alert("Hello," + this.message)
    }
  },
  created() {
    // 组件创建时执行，会调用created方法 ，通常用来发请求
    console.log("组件创建了,message的值为:", this.message)
  }
}
</script>

<!-- Add "scoped" attribute to limit CSS to this component only -->
<style scoped>

</style>
