function createSpace() {
    const spaceName = prompt('Enter the name of your new space:');
    if (spaceName) {
        fetch('/spaces', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(spaceName),
        }).then(response => {
            if (response.ok) {
                location.reload();
            } else {
                alert('Failed to create space.');
            }
        });
    }
}
