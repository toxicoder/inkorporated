document.addEventListener('DOMContentLoaded', function() {
  const searchInput = document.getElementById('search-input');
  const searchResultsContainer = document.getElementById('search-results');
  let searchData = [];

  // Debounce function
  function debounce(func, wait) {
    let timeout;
    return function() {
      const context = this;
      const args = arguments;
      clearTimeout(timeout);
      timeout = setTimeout(() => func.apply(context, args), wait);
    };
  }

  if (searchInput) {
    // Fetch search data
    const searchUrl = window.searchUrl || '/search.json';
    fetch(searchUrl)
      .then(response => response.json())
      .then(data => {
        searchData = data;
      })
      .catch(error => console.error('Error fetching search data:', error));

    const handleSearch = function() {
      const query = this.value.toLowerCase();
      searchResultsContainer.innerHTML = '';

      if (query.length < 2) {
        return; // Don't search for short queries
      }

      const results = searchData.filter(item => {
        return item.title.toLowerCase().includes(query) ||
               (item.content && item.content.toLowerCase().includes(query));
      });

      if (results.length > 0) {
        results.slice(0, 5).forEach(result => {
          const link = document.createElement('a');
          link.href = result.url;
          link.textContent = result.title;
          searchResultsContainer.appendChild(link);
        });
      } else {
        const noResults = document.createElement('div');
        noResults.style.padding = '8px 12px';
        noResults.style.color = 'var(--md-sys-color-on-surface-variant)';
        noResults.style.fontSize = '13px';
        noResults.textContent = 'No results found';
        searchResultsContainer.appendChild(noResults);
      }
    };

    // Apply debounce
    searchInput.addEventListener('input', debounce(handleSearch, 300));

    // Close results when clicking outside
    document.addEventListener('click', function(e) {
      if (!searchInput.contains(e.target) && !searchResultsContainer.contains(e.target)) {
        searchResultsContainer.innerHTML = '';
      }
    });
  }
});
