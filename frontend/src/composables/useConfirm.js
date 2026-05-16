import { ref } from 'vue'

const visible = ref(false)
const dialogOptions = ref({ title: 'Confirm', message: '' })
let _resolve = null

export function useConfirm() {
  function confirm(message, title = 'Confirm') {
    dialogOptions.value = { title, message }
    visible.value = true
    return new Promise(resolve => { _resolve = resolve })
  }

  function accept() {
    visible.value = false
    if (_resolve) { _resolve(true); _resolve = null }
  }

  function cancel() {
    visible.value = false
    if (_resolve) { _resolve(false); _resolve = null }
  }

  return { visible, dialogOptions, confirm, accept, cancel }
}
