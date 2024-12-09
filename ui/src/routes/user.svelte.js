export let users = $state([]);
export let userId = $state(null);
export let user = $derived((users || []).find(u => u.id === userId));
