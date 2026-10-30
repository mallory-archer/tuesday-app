const namesList = document.querySelector("#names");
const averagesList = document.querySelector("#averages");
const error = document.querySelector("#error");

function showError(message) {
  error.hidden = false;
  error.textContent = message;
}

fetch("/api/class")
  .then((response) => {
    if (!response.ok) {
      throw new Error("Could not load class data");
    }
    return response.json();
  })
  .then((data) => {
    if (data.names.length === 0) {
      const item = document.createElement("li");
      item.textContent = "No students";
      namesList.append(item);
    }
    for (const name of data.names) {
      const item = document.createElement("li");
      item.textContent = name;
      namesList.append(item);
    }
    for (const skill of data.averages) {
      const item = document.createElement("li");
      const value = skill.average === null ? "—" : skill.average.toFixed(2);
      item.textContent = `${skill.label}: ${value}`;
      averagesList.append(item);
    }
  })
  .catch((err) => {
    showError(err.message);
  });
